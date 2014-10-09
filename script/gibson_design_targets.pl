#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use Text::CSV;
use Getopt::Long;
use LIMS2::Util::EnsEMBL;
use Log::Log4perl ':easy';
use List::MoreUtils qw( all );
use IO::File;
use Pod::Usage;
use DDP colored => 1;
use Const::Fast;
use YAML::Any qw( LoadFile );

my $log_level = $WARN;
GetOptions(
    'help'                 => sub { pod2usage( -verbose    => 1 ) },
    'man'                  => sub { pod2usage( -verbose    => 2 ) },
    'debug'                => sub { $log_level = $DEBUG },
    'verbose'              => sub { $log_level = $INFO },
    'trace'                => sub { $log_level = $TRACE },
    'genes-file=s'         => \my $genes_file,
    'gene=s'               => \my $single_gene,
    'base-design-params=s' => \my $base_params_file,
    'strict'               => \my $strict,
    'species=s'            => \my $species,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );
LOGDIE( 'Specify file with gene names' ) unless $genes_file;
$species ||= 'Human';
LOGDIE( 'Must specify species' ) unless $species;

const my $DEFAULT_ASSEMBLY => $species eq 'Human' ? 'GRCh38' :  $species eq 'Mouse' ? 'GRCm38' : undef;
const my $DEFAULT_BUILD => 76;

LOGDIE( "Can not work out default assembly for species $species" ) unless $DEFAULT_ASSEMBLY;

WARN( "ASSEMBLY: $DEFAULT_ASSEMBLY, BUILD: $DEFAULT_BUILD" );

my $base_params;
$base_params = LoadFile( $base_params_file ) if $base_params_file;

const my @DESIGN_COLUMN_HEADERS => (
'target-gene',
'target-exon',
keys %{ $base_params }
);

const my @TARGET_COLUMN_HEADERS => (
'gene_id',
'marker_symbol',
'ensembl_gene_id',
'ensembl_exon_id',
'exon_size',
'exon_rank',
'canonical_transcript',
'assembly',
'build',
'species',
'chr_name',
'chr_start',
'chr_end',
'chr_strand',
'automatically_picked',
'comment',
);

const my @FAILED_TARGETS_HEADERS => qw(
gene_id
marker_symbol
ensembl_id
ensembl_id_b
);

my $ensembl_util = LIMS2::Util::EnsEMBL->new( species => $species );
my $db = $ensembl_util->db_adaptor;
my $db_details = $db->to_hash;
WARN("Ensembl DB: " . $db_details->{'-DBNAME'});

my ( $target_output, $target_output_csv, $design_output, $design_output_csv, $failed_output, $failed_output_csv );
$target_output = IO::File->new( 'target_parameters.csv' , 'w' );
$target_output_csv = Text::CSV->new( { eol => "\n" } );
$target_output_csv->print( $target_output, \@TARGET_COLUMN_HEADERS );

$failed_output = IO::File->new( 'failed_targets.csv' , 'w' );
$failed_output_csv = Text::CSV->new( { eol => "\n" } );
$failed_output_csv->print( $failed_output, \@FAILED_TARGETS_HEADERS );

if ( $base_params_file ) {
    $design_output = IO::File->new( 'design_parameters.csv' , 'w' );
    $design_output_csv = Text::CSV->new( { eol => "\n" } );
    $design_output_csv->print( $design_output, \@DESIGN_COLUMN_HEADERS );
}

my @failed_targets;

## no critic(InputOutput::RequireBriefOpen)
{
    my $input_csv = Text::CSV->new();
    open ( my $input_fh, '<', $genes_file ) or die( "Can not open $genes_file " . $! );
    $input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );
    while ( my $data = $input_csv->getline_hr( $input_fh ) ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $data->{gene_id} );
        Log::Log4perl::NDC->push( $data->{marker_symbol} );
        next if $single_gene && $single_gene ne $data->{marker_symbol};

        try{
            process_target( $data );
        }
        catch{
            ERROR('Problem processing target: ' . $_ );
            push @failed_targets, $data;
        };
    }
    for my $failed_target ( @failed_targets ) {
        $failed_output_csv->print( $failed_output, [ @{ $failed_target }{ @FAILED_TARGETS_HEADERS } ] );
    }
    close $input_fh;
}
## use critic

sub process_target {
    my $data = shift;
    my $ensembl_id = get_ensembl_id( $data );
    return unless $ensembl_id;

    INFO( 'Target gene: ' . $ensembl_id );
    my $gene = $ensembl_util->gene_adaptor->fetch_by_stable_id( $ensembl_id );
    unless ( $gene ) {
        ERROR( "Can not find ensembl gene: " . $ensembl_id );
        push @failed_targets, $data;
        return;
    }

    my @exons = @{ get_all_critical_exons( $gene, $data ) };
    unless ( @exons ) {
        ERROR('Unable to find any valid critical exons');
        push @failed_targets, $data;
        return;
    }

    my $count = 0;
    for my $exon ( @exons ) {
        last if $count > 4;
        print_design_targets( $exon, $gene, $data );
        $count++;
    }

    return;
}

sub get_ensembl_id {
    my $data = shift;

    if ( $data->{ensembl_id} ) {
        if ( $data->{ensembl_id_b} ) {
           if ( $data->{ensembl_id} eq $data->{ensembl_id_b} ) {
               return $data->{ensembl_id}
           }
           else {
               ERROR( 'Mismatch in ensembl ids: ' . $data->{ensembl_id} . ' and ' . $data->{ensembl_id_b});
               push @failed_targets, $data;
               return;
           }
        }
        else {
            return $data->{ensembl_id}
        }
    }
    else {
        if ( $data->{ensembl_id_b} ) {
            return $data->{ensembl_id_b}
        }
        else {
            ERROR( 'No Ensembl ID found' );
            push @failed_targets, $data;
            return;
        }
    }

    return;
}

=head2 print_design_targets

We need 2 output csv files, one listing the design targets and another
with the paremeters to feed into the Design Creation process.

=cut
sub print_design_targets {
    my ( $exon, $gene, $data ) = @_;

    if ( $base_params_file ) {
        my %design_params = %{ $base_params };
        $design_params{'target-gene'} = $data->{gene_id};
        $design_params{'target-exon'} = $exon->stable_id;

        $design_output_csv->print( $design_output, [ @design_params{ @DESIGN_COLUMN_HEADERS } ] );
    }

    my %target_params = (
        species              => $species,
        assembly             => $DEFAULT_ASSEMBLY,
        build                => $DEFAULT_BUILD,
        automatically_picked => 1,
    );

    if ( $data->{exon_ids} ) {
        $target_params{ 'comment' } = $data->{comment} if $data->{comment};
        $target_params{ 'automatically_picked' } = 0;
    }

    my $canonical_transcript = $gene->canonical_transcript;
    my $exon_rank = get_exon_rank( $exon, $canonical_transcript );

    $target_params{ 'gene_id' } = $data->{gene_id};
    $target_params{ 'marker_symbol' } = $data->{marker_symbol};
    $target_params{ 'ensembl_gene_id' } = $gene->stable_id;
    $target_params{ 'ensembl_exon_id' } = $exon->stable_id;
    $target_params{ 'exon_size' } = $exon->length;
    $target_params{ 'exon_rank' } = $exon_rank;
    $target_params{ 'canonical_transcript' } = $canonical_transcript->stable_id;
    $target_params{ 'chr_name' } = $exon->seq_region_name;
    $target_params{ 'chr_start' } = $exon->seq_region_start;
    $target_params{ 'chr_end' } = $exon->seq_region_end;
    $target_params{ 'chr_strand' } = $exon->seq_region_strand;

    $target_output_csv->print( $target_output, [ @target_params{ @TARGET_COLUMN_HEADERS } ] );

    return;
}

=head2 get_exon_rank

Get rank of exon on canonical transcript

=cut
sub get_exon_rank {
    my ( $exon, $canonical_transcript ) = @_;

    my $rank = 1;
    for my $current_exon ( @{ $canonical_transcript->get_all_Exons } ) {
        return $rank if $current_exon->stable_id eq $exon->stable_id;
        $rank++;
    }

    return 0;
}

=head2 get_all_critical_exons

All exons for the gene that are:
- constitutive ( belong to all coding transcipts )
- induce a phase shift if removed
- less than 300 bases

Return list of exons sorted on ascending length

=cut
sub get_all_critical_exons {
    my ( $gene, $data ) = @_;

    return get_predefined_exons( $data->{exon_ids}, $gene, $data ) if $data->{exon_ids};

    my %valid_exons;
    my %transcript_exons;
    my @coding_transcript_names;

    my @coding_transcripts = grep{ valid_coding_transcript($_) } @{ $gene->get_all_Transcripts };

    unless ( @coding_transcripts ) {
        WARN( 'Can not find coding transcripts for gene: ' . $gene->stable_id );
        return [];
    }

    for my $tran ( @coding_transcripts ) {
        push @coding_transcript_names, $tran->stable_id;
        find_valid_exons( $tran, \%valid_exons, \%transcript_exons );
    }
    unless ( keys %valid_exons ) {
        WARN( 'No valid exons for gene: ' . $gene->stable_id );
        return [];
    }
    DEBUG( 'Valid Exon Transcripts: ' . p( %transcript_exons ) );
    DEBUG( 'Valid Coding Transcripts: ' . p( @coding_transcript_names ) );

    my $critical_exons_ids = find_critical_exons( \%transcript_exons, \@coding_transcript_names );

    unless ( $critical_exons_ids ) {
        WARN( 'No critical exons for gene: ' . $gene->stable_id );
        return [];
    }

    my @valid_critical_exons;
    while ( my ( $exon_id, $exon ) = each %valid_exons ) {
        push @valid_critical_exons, $valid_exons{ $exon_id }
            if exists $critical_exons_ids->{ $exon_id };
    }

    unless ( @valid_critical_exons ){
        WARN( 'No valid exons that are also critical for gene ' . $gene->stable_id );
        return [];
    }

    if ( $strict ) {
        my @copy_critical_exons = @valid_critical_exons;
        @valid_critical_exons = grep{ exons_not_too_close( $_ ) } @copy_critical_exons;

        unless ( @valid_critical_exons ){
            WARN( 'No valid critical exons pass exon closeness check for gene ' . $gene->stable_id );
            return [];
        }
    }

    my $num_critical_exons = @valid_critical_exons;
    INFO( "Has $num_critical_exons critical exons" );

    my @ordered_critical_exons = sort most_five_prime @valid_critical_exons;

    #if we have multiple critical exons we skip the exon with the start codon
    if ( $num_critical_exons > 1 ) {
        my %start_exons;
        for my $tran ( @coding_transcripts ) {
            my $exon_id = $tran->start_Exon->stable_id;
            $start_exons{ $exon_id } = 1;
        }

        return [ grep{ !exists $start_exons{$_->stable_id} } @ordered_critical_exons ];
    }

    return \@ordered_critical_exons;
}

=head2 get_predefined_exons

If exons targets have been pre-defined in the input use these
instead of trying to calculate the target exons.

=cut
sub get_predefined_exons {
    my ( $exon_ids, $gene, $data ) = @_;
    my @exons;
    my @exon_ids = split /,/, $data->{exon_ids};

    my %gene_exons = map{ $_->stable_id => 1 } @{ $gene->get_all_Exons };
    for my $exon_id ( @exon_ids ) {
        unless ( exists $gene_exons{$exon_id} ) {
            ERROR("The exon $exon_id can not be found on the gene: " . $gene->stable_id);
            next;
        }
        my $exon = $ensembl_util->exon_adaptor->fetch_by_stable_id( $exon_id );
        LOGDIE("Can not find specified exon $exon_id") unless $exon;
        push @exons, $exon;
    }

    return \@exons;
}

=head2 find_valid_exons

Exons that are less than 300 bases and will induce a phase shift

Create hash of valid exons, keyed on stable id
Create hash of exons for each transcript, keyed on transcript stable id

=cut
sub find_valid_exons {
    my ( $transcript, $valid_exons, $transcript_exons ) = @_;
    my @valid_exons;
    my @exons = @{ $transcript->get_all_Exons };

    for my $exon ( @exons ) {

        my $exon_length = $exon->length;
        if ( $exon_length > 300 ) {
            TRACE( 'Exon ' . $exon->stable_id . " is too long: $exon_length" );
            next;
        }
        if ( $exon_length % 3 == 0  ) {
            TRACE( 'Exon ' . $exon->stable_id . " removal would not create frame shift" );
            next;
        }

        # skip exons which are non-coding
        unless ( $exon->coding_region_start( $transcript ) ) {
            INFO( 'Exon ' . $exon->stable_id . " is non coding in transcript " , $transcript->stable_id );
            next;
        }

        if ( $strict ) {
            next if too_few_exon_coding_bases( $exon, $transcript );
        }

        TRACE( 'Exon ' . $exon->stable_id . ' is VALID' );
        push @valid_exons, $exon;
    }

    for my $exon ( @valid_exons ) {
        push @{ $transcript_exons->{ $exon->stable_id } }, $transcript->stable_id;
        $valid_exons->{ $exon->stable_id } = $exon
            unless exists $valid_exons->{ $exon->stable_id };
    }

    return;
}

=head2 exons_not_too_close

For gibson designs we don't want other exons within around
400 bases of the critical exon

=cut
sub exons_not_too_close {
    my ( $critical_exon, $transcript_exons ) = @_;
    my $critical_exon_id = $critical_exon->stable_id;

    my $exon_slice = $critical_exon->feature_Slice;
    my $expanded_slice = $exon_slice->expand( 400, 400 );
    my $expanded_slice_start = $expanded_slice->start;
    my $expanded_slice_end = $expanded_slice->end;

    my @flanking_exons;
    # grab all genes that overlap this slice, including on reverse strand
    my $genes = $expanded_slice->get_all_Genes;

    for my $gene ( @{ $genes } ) {
        my $canonical_transcript = $gene->canonical_transcript;

        for my $exon ( @{ $canonical_transcript->get_all_Exons } ) {
            next if $exon->stable_id eq $critical_exon_id;
            if (   ( $expanded_slice_start < $exon->start && $expanded_slice_end > $exon->start )
                || ( $expanded_slice_start < $exon->end && $expanded_slice_end > $exon->end ) )
            {
                push @flanking_exons, $exon;
            }
        }
    }

    if ( @flanking_exons ) {
        DEBUG( "Exon $critical_exon_id has another exon within 400 bases: " . join(' ', map{ $_->stable_id } @flanking_exons ) );
        return;
    }

    return 1;
}

=head2 too_few_exon_coding_bases

return true if exon does not have at least 30 coding bases

=cut
sub too_few_exon_coding_bases {
    my ( $exon, $transcript ) = @_;

    my $length = $exon->cdna_coding_end( $transcript ) - $exon->cdna_coding_start( $transcript ) + 1;

    if ( $length < 30 ) {
        DEBUG( 'Exon ' . $exon->stable_id . " only has $length coding bases " );
        return 1;
    }
    else {
        return;
    }
}

=head2 find_critical_exons

Find exons that belong to all coding transcripts

=cut
sub find_critical_exons {
    my ( $transcript_exons, $coding_transcript_names ) = @_;
    my %critical_exons;

    for my $exon ( keys %{ $transcript_exons } ) {
        my %transcripts = map{ $_ => 1  } @{ $transcript_exons->{$exon} };

        if ( all { exists $transcripts{ $_ } } @{ $coding_transcript_names } ) {
            TRACE( "Exon $exon is critical" );
            $critical_exons{ $exon } = 1;
        }
        else {
            TRACE( "Exon $exon not present in all valid transcripts" );
        }
    }
    return unless keys %critical_exons;

    return \%critical_exons;
}

=head2 valid_coding_transcript

Return true if the transcript is a valid transcript by our measure:
Not nonsense mediated decay.
CDS region in complete ( has proper start and end ).

=cut
sub valid_coding_transcript {
    my ( $transcript ) = @_;
    my $id = $transcript->stable_id;

    TRACE( "$id biotype: " . $transcript->biotype );
    if ( !$transcript->translation ) {
        TRACE("Transcript $id is non protein coding");
        return 0;
    }

    if ( $transcript->biotype eq 'nonsense_mediated_decay') {
        TRACE("Transcript $id is NMD");
        return 0;
    }

    # CDS incomplete check, both 5' and 3'
    if ( _get_transcript_attribute( $transcript, 'cds_end_NF' ) ) {
        TRACE("Transcript $id has incomplete CDS end");
        return 0;
    }

    if ( _get_transcript_attribute( $transcript, 'cds_start_NF' ) ) {
        TRACE("Transcript $id has incomplete CDS start");
        return 0;
    }

    TRACE("Transcript $id is VALID");
    return 1;
}

=head2 most_five_prime

Rank critical exons by following criteria by closest to 5 prime

=cut
## no critic(RequireFinalReturn)
sub most_five_prime {
    if ( $a->strand == 1 ) {
        $a->start <=> $b->start;
    }
    else {
        $b->start <=> $a->start;
    }
}
## use critic

sub _get_transcript_attribute {
    my ( $transcript, $code ) = @_;

    my ( $attr ) = @{ $transcript->get_all_Attributes($code) };
    if ( $attr ) {
        return $attr->value();
    }
    return 0;
}

__END__

=head1 NAME

gibson_design_targets.pl - Create design targets list given list of gene names.

=head1 SYNOPSIS

  gibson_design_targets.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output
      --trace           Trace output
      --genes-file      File with genes names.
      --gene            Specify only one gene from the file
      --species         Species of targets ( default Human )
      --strict          More strict target criteria

      The genes file should be a csv file with 3 column headers: gene_id, marker_symbol and ensembl_id.
      The gene_id column will use HGNC ids or MGI ID's
      A fourth optionally column is exon_ids if the critical exons have been pre-defined.

=head1 DESCRIPTION

Given a list of gene targets, find the critical exons for that gene and write out a file
with design parameters to target those critical exons.

For our purposes a critical exon is:
- Constitutive
- Would induce a phase shift if removed
- Less than 300 bases long.

Exons are ranked according to which is most five prime.
Currently a maximum of 5 critical exons are found for each gene target.

If the strict option is given following criteria adde:
- Exon must have at least 30 coding bases
- Exon must not have another exon within 400 bases on either side

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
