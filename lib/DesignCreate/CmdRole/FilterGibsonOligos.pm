package DesignCreate::CmdRole::FilterGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FilterGibsonOligos::VERSION = '0.020';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::FilterGibsonOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use Moose::Role;
use DesignCreate::Exception;
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( NaturalNumber PositiveInt );
use DesignCreate::Util::BWA;
use DesignCreate::Constants qw( $DEFAULT_BWA_OLIGO_DIR_NAME %GIBSON_PRIMER_REGIONS );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use List::MoreUtils qw( any );
use namespace::autoclean;
use Bio::SeqIO;
use Try::Tiny;

with qw(
DesignCreate::Role::FilterOligos
);

const my @DESIGN_PARAMETERS => qw(
exon_check_flank_length
oligo_three_prime_align
);

has exon_check_flank_length => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Number of flanking bases surrounding middle oligos to check for exons,'
                     . ' set to 0 to turn off check',
    cmd_flag      => 'exon-check-flank-length',
    default       => 0,
);

has oligo_three_prime_align => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Oligo alignment check looks at three prime mismatches ( default false )',
    cmd_flag      => 'oligo-three-prime-align',
    default       => 0,
);

has num_bwa_threads => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Number of threads bwa aln will use ( default 2 )',
    cmd_flag      => 'num-bwa-threads',
    default       => 2,
);

has bwa_query_file => (
    is     => 'rw',
    isa    => AbsFile,
    traits => [ 'NoGetopt' ],
);

has bwa_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_bwa_dir {
    my $self = shift;

    my $bwa_oligo_dir = $self->dir->subdir( $DEFAULT_BWA_OLIGO_DIR_NAME )->absolute;
    $bwa_oligo_dir->rmtree();
    $bwa_oligo_dir->mkpath();

    return $bwa_oligo_dir;
}

has bwa_matches => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

has critical_exons => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        is_critical_exon => 'exists',
    }
);

=head2 _build_critical_exons

Build a hash of the critical exons that are targeted by the design.

=cut
sub _build_critical_exons {
    my $self = shift;
    my %critical_exons;

    if ( my $three_prime_exon = $self->design_param( 'three_prime_exon' ) ) {
        # have both a 5' and 3' exon
        #TODO should really work out all exons inbetween 5' and 3' exon sp12 Wed 29 Jan 2014 11:41:19 GMT
        #     but that could be tricky and check can easily be turned off
        $critical_exons{ $three_prime_exon } = 1;
    }
    $critical_exons{ $self->design_param( 'five_prime_exon' ) } = 1;

    return \%critical_exons;
}

has validated_oligo_pairs => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'Hash', 'NoGetopt' ],
    default => sub{ {} },
    handles => {
        get_valid_pairs        => 'get',
        region_has_oligo_pairs => 'exists',
    }
);

sub filter_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->run_bwa;

    # the following 2 commands are consumed from DesignCreate::Role::FilterOligos
    $self->validate_oligos;
    $self->output_validated_oligos;

    $self->validate_oligo_pairs;
    $self->output_valid_oligo_pairs;
    $self->update_design_attempt_record( { status => 'oligos_validated' } );

    return;
}

=head2 _validate_oligo

Run checks against individual oligo to make sure it is valid.
If it passes all checks return 1, otherwise return undef.

=cut
## no critic(Subroutines::ProhibitUnusedPrivateSubroutine)
sub _validate_oligo {
    my ( $self, $oligo_data, $oligo_type, $oligo_slice, $invalid_reason ) = @_;
    $self->log->debug( "$oligo_type oligo, id: " . $oligo_data->{id} );

    $self->check_oligo_sequence( $oligo_data, $oligo_slice, $invalid_reason ) or return;
    $self->check_oligo_length( $oligo_data, $invalid_reason )                 or return;
    if ( $oligo_type =~ /5R|EF|ER|3F/ ) {
        $self->check_oligo_not_near_exon( $oligo_data, $oligo_slice, $invalid_reason ) or return;
    }

    $self->check_oligo_specificity(
        $oligo_data->{id},
        $self->bwa_matches->{ $oligo_data->{id} },
        $invalid_reason,
    ) or return;

    return 1;
}
## use critic

=head2 check_oligo_not_near_exon

Check that the oligo is not within a certain number of bases of a exon

=cut
sub check_oligo_not_near_exon {
    my ( $self, $oligo_data, $oligo_slice, $invalid_reason ) = @_;
    return 1 if $self->exon_check_flank_length == 0;

    my $expanded_slice
        = $oligo_slice->expand( $self->exon_check_flank_length, $self->exon_check_flank_length );
    my $expanded_slice_start = $expanded_slice->start;
    my $expanded_slice_end = $expanded_slice->end;

    # grab all genes that overlap this slice, including on reverse strand
    my $genes = $expanded_slice->get_all_Genes;

    my @flanking_exons;
    for my $gene ( @{ $genes } ) {
        my $canonical_transcript = $gene->canonical_transcript;

        for my $exon ( @{ $canonical_transcript->get_all_Exons } ) {
            next if $self->is_critical_exon( $exon->stable_id );
            if (   ( $expanded_slice_start < $exon->start && $expanded_slice_end > $exon->start )
                || ( $expanded_slice_start < $exon->end && $expanded_slice_end > $exon->end ) )
            {
                push @flanking_exons, $exon;
            }
        }
    }
    # if no exons in slice we pass the check
    return 1 unless @flanking_exons;

    my $exon_ids = join( ', ', map { $_->stable_id } @flanking_exons );
    $self->log->debug(
        'Oligo ' . $oligo_data->{id} . " overlaps or is too close to exon(s): $exon_ids" );
    $$invalid_reason = "Too close to exons $exon_ids";

    return 0;
}

sub validate_oligo_pairs {
    my $self = shift;

    my $design_method = $self->design_param( 'design_method' );
    for my $oligo_pair_region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
        my $oligo_pair_file
            = $self->get_file( $oligo_pair_region . '_oligo_pairs.yaml', $self->oligo_finder_output_dir );

        my $oligo_pairs = LoadFile( $oligo_pair_file );
        DesignCreate::Exception->throw("No oligo pair data in $oligo_pair_file")
            unless $oligo_pairs;

        for my $pair ( @{ $oligo_pairs } ) {
            next if any{ $self->oligo_is_invalid( $_ ) } values %{ $pair };

            push @{ $self->validated_oligo_pairs->{ $oligo_pair_region } }, $pair;
        }
    }

    return;
}

sub output_valid_oligo_pairs {
    my $self = shift;

    my $design_method = $self->design_param( 'design_method' );
    for my $oligo_pair_region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
        DesignCreate::Exception->throw( "No valid oligo pairs for $oligo_pair_region oligo region" )
            unless $self->region_has_oligo_pairs( $oligo_pair_region );

        #TODO if we add ranking of oligos this needs to use that sp12 Mon 09 Sep 2013 08:48:03 BST
        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_pair_region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_valid_pairs( $oligo_pair_region ) );
    }

    return;
}

=head2 check_oligo_specificity

Filter out oligos that have mulitple hits against the reference genome.

=cut
sub check_oligo_specificity {
    my ( $self, $oligo_id, $match_info, $invalid_reason ) = @_;
    # if we have no match info then fail oligo
    return unless $match_info;

    #TODO implement three_prime_align checks sp12 Mon 07 Oct 2013 11:14:29 BST
    if ( $self->oligo_three_prime_align ) {
        if ( !$match_info->{exact_matches} ) {
            $self->log->error( "Oligo $oligo_id does not have any exact matches, somethings wrong" );
            return;
        }
        elsif ( $match_info->{exact_matches} > 1 ) {
            $self->log->info( "Oligo $oligo_id is invalid, has multiple exact matches: "
                . $match_info->{exact_matches} );
            return;
        }
        # a hit is above 90% similarity
        elsif ( $match_info->{hits} >=  1 ) {
            $self->log->info( "Oligo $oligo_id is invalid, has multiple hits: " . $match_info->{hits} );
            return;
        }
    }
    else {
        if ( !$match_info->{unique_alignment} ) {
            $self->log->trace( "Oligo $oligo_id has no a unique alignment");
            $$invalid_reason = "No unique genomic alignment";
            return;
        }
        # a hit is above 90% similarity
        elsif ( exists $match_info->{hits} && $match_info->{hits} >= 1 ) {
            $self->log->debug( "Oligo $oligo_id is invalid, has multiple hits: " . $match_info->{hits} );
            $$invalid_reason = "Multiple genomic hits: " . $match_info->{hits};
            return;
        }
    }

    return 1;
}

sub run_bwa {
    my $self = shift;
    $self->define_bwa_query_file;

    my $bwa = DesignCreate::Util::BWA->new(
        query_file        => $self->bwa_query_file,
        work_dir          => $self->bwa_dir,
        species           => $self->design_param( 'species' ),
        three_prime_check => $self->oligo_three_prime_align,
        num_bwa_threads   => $self->num_bwa_threads,
    );

    try{
        $bwa->run_bwa_checks;
    }
    catch{
        DesignCreate::Exception->throw("Error running bwa " . $_);
    };

    $self->bwa_matches( $bwa->matches );

    return;
}

sub define_bwa_query_file {
    my $self = shift;

    my $query_file = $self->bwa_dir->file('bwa_query.fasta');
    my $fh         = $query_file->open( O_WRONLY|O_CREAT ) or die( "Open $query_file: $!" );
    my $seq_out    = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo_type ( keys %{ $self->all_oligos } ) {
        for my $oligo ( @{ $self->all_oligos->{$oligo_type} } ) {
            my $bio_seq  = Bio::Seq->new( -seq => $oligo->{oligo_seq}, -id => $oligo->{id} );
            $seq_out->write_seq( $bio_seq );
        }
    }

    $self->log->debug("Created bwa query file $query_file");
    $self->bwa_query_file( $query_file );
    return;
}

1;

__END__
