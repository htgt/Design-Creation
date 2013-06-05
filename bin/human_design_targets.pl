#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use Text::CSV;
use Getopt::Long;
use LIMS2::Util::EnsEMBL;
use Log::Log4perl ':easy';
use List::MoreUtils qw( all );
use IO::Handle;
use Pod::Usage;
use DDP colored => 1;
use Const::Fast;

my $log_level = $WARN;
GetOptions(
    'help'          => sub { pod2usage( -verbose => 1 ) },
    'man'           => sub { pod2usage( -verbose => 2 ) },
    'debug'         => sub { $log_level = $DEBUG },
    'verbose'       => sub { $log_level = $INFO },
    'trace'         => sub { $log_level = $TRACE },
    'genes-file=s'  => \my $genes_file,
    'gene=s'        => \my $single_gene,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );
LOGDIE( 'Specify file with gene names' ) unless $genes_file;

const my %BASE_DESIGN_PARAMETERS => (
    'd3-region-length'   => 100,
    'd3-region-offset'   => 10,
    'u5-region-length'   => 100,
    'u5-region-offset'   => 30,
    'g3-region-length'   => 500,
    'g3-region-offset'   => 1000,
    'g5-region-length'   => 500,
    'g5-region-offset'   => 1000,
    'design-method'      => 'deletion',
    'species'            => 'Human',
    'mask-by-lower-case' => 'yes'
);

const my @COLUMN_HEADERS => (
'target-gene',
'ensembl-gene',
'target-exon',
'exon-size',
'exon-rank',
keys %BASE_DESIGN_PARAMETERS
);

my $ensembl_util = LIMS2::Util::EnsEMBL->new( species => 'Human' );

my $io_output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $io_output, \@COLUMN_HEADERS );

## no critic(InputOutput::RequireBriefOpen)
{
    my $input_csv = Text::CSV->new();
    open ( my $input_fh, '<', $genes_file ) or die( "Can not open $genes_file " . $! );
    $input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );
    while ( my $data = $input_csv->getline_hr( $input_fh ) ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $data->{hgnc_symbol} );
        Log::Log4perl::NDC->push( $data->{ensembl_id} );
        next if $single_gene && $single_gene ne $data->{hgnc_symbol};
        try{
            process_target( $data );
        }
        catch{
            ERROR('Problem processing target: ' . $_ );
        };
    }
    close $input_fh;
}
## use critic

sub process_target {
    my $data = shift;
    unless ( $data->{ensembl_id} ) {
        WARN( 'Need ensembl id, none given for' );
        return;
    }

    INFO( 'Target gene: ' . $data->{ensembl_id} );
    my $gene = $ensembl_util->gene_adaptor->fetch_by_stable_id( $data->{ensembl_id} );
    unless ( $gene ) {
        ERROR( "Can not find ensembl gene: " . $data->{ensembl_id} );
        return;
    }

    my @exons = @{ get_all_critical_exons( $gene, $data ) };
    unless ( @exons ) {
        ERROR('Unable to find any valid critical exons');
        return;
    }

    my $count = 0;
    for my $exon ( @exons ) {
        last if $count > 4;
        print_design_parameters( $exon, $gene, $data->{hgnc_symbol} );
        $count++;
    }

    return;
}

sub print_design_parameters {
    my ( $exon, $gene, $gene_id ) = @_;

    my $exon_rank = get_exon_rank( $exon, $gene );

    my %design_params = %BASE_DESIGN_PARAMETERS;
    $design_params{'target-gene'} = $gene_id;
    $design_params{'ensembl-gene'} = $gene->stable_id;
    $design_params{'target-exon'} = $exon->stable_id;
    $design_params{'exon-size'} = $exon->length;
    $design_params{'exon-rank'} = $exon_rank;

    $output_csv->print( $io_output, [ @design_params{ @COLUMN_HEADERS } ] );

    return;
}

sub get_exon_rank {
    my ( $exon, $gene ) = @_;

    my $canonical_transcript = $gene->canonical_transcript;
    INFO( 'Canonical transcript: ' . $canonical_transcript->stable_id );

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
        ERROR( 'Can not find coding transcripts for gene: ' . $gene->stable_id );
        return [];
    }

    for my $tran ( @coding_transcripts ) {
        push @coding_transcript_names, $tran->stable_id;
        find_valid_exons( $tran, \%valid_exons, \%transcript_exons );
    }

    DEBUG( 'Valid Coding Transcripts: ' . p( @coding_transcript_names ) );
    DEBUG( 'Valid Exon Transcripts: ' . p( %transcript_exons ) );

    my $critical_exons_ids = find_critical_exons( \%transcript_exons, \@coding_transcript_names );
    my @critical_exons;
    for my $exon_id ( keys %valid_exons ) {
        push @critical_exons, $valid_exons{ $exon_id }
            if exists $critical_exons_ids->{ $exon_id };
    }

    my $num_critical_exons = @critical_exons;
    INFO( "Has $num_critical_exons critical exons" );

    my @ordered_critical_exons = sort most_five_prime @critical_exons;

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

# exons that are less than 300 bases and will induce a phase shift
sub find_valid_exons {
    my ( $transcript, $valid_exons, $transcript_exons ) = @_;
    my @critical_exons;
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

        TRACE( 'Exon ' . $exon->stable_id . ' is VALID' );
        push @critical_exons, $exon;
    }

    for my $exon ( @critical_exons ) {
        push @{ $transcript_exons->{ $exon->stable_id } }, $transcript->stable_id;
        $valid_exons->{ $exon->stable_id } = $exon
            unless exists $valid_exons->{ $exon->stable_id };
    }

    return;
}

# find exons that belong to all coding transcripts
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

human_design_targets.pl - Create human design targets list given list of gene names.

=head1 SYNOPSIS

  human_design_targets.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output
      --trace           Trace output
      --genes-file      File with genes names.
      --gene            Specify only one gene from the file

      The genes file should be a csv file with 2 column headers: hgnc_symbol and ensembl_id.
      A third optionally column is exon_id if the critical exons have been pre-defined.

=head1 DESCRIPTION

Given a list of gene targets, find the critical exons for that gene and write out a file
with design parameters to target those critical exons.

For our purposes a critical exon is:
- Constitutive
- Would induce a phase shift if removed
- Less than 300 bases long.

Exons are ranked according to which is most five prime.
Currently a maximum of 5 critical exons are found for each gene target.

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
