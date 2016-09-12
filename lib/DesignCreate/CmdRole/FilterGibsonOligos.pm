package DesignCreate::CmdRole::FilterGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FilterGibsonOligos::VERSION = '0.042';
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
use DesignCreate::Exception::OligoPairRegionValidation;
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( NaturalNumber PositiveInt );
use DesignCreate::Util::BWA;
use DesignCreate::Constants qw( $DEFAULT_BWA_OLIGO_DIR_NAME %GIBSON_PRIMER_REGIONS );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use List::MoreUtils qw( any );
use List::Util qw( sum );
use Bio::SeqIO;
use Try::Tiny;
use JSON;
use namespace::autoclean;

with qw(
DesignCreate::Role::FilterOligos
);

const my @DESIGN_PARAMETERS => qw(
exon_check_flank_length
oligo_three_prime_align
num_genomic_hits
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

has num_genomic_hits => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Maximum number of genomic hits a oligos is allowed, default is just 1 hit',
    cmd_flag      => 'num-genomic-hits',
    default       => 1,
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

has region_best_primer3_pair => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'Hash', 'NoGetopt' ],
    default => sub{ {} },
    handles => {
        get_region_best_primer3_pair  => 'get',
        set_region_best_primer3_pair  => 'set',
    }
);

sub filter_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->run_bwa;

    try{
        $self->validate_oligos; # DesignCreate::Role::FilterOligos
    }
    catch{
        # If we throw a error, we still want to show candidate oligos
        # to the user ( we have all the required oligos but not all of
        # them will be valid, this could be useful to the user ).
        $self->validate_oligo_pairs;
        $self->update_candidate_oligos_after_validation;
        die $_;
    };
    $self->validate_oligo_pairs;
    $self->update_candidate_oligos_after_validation;

    $self->output_validated_oligos; # DesignCreate::Role::FilterOligos
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

=head2 validate_oligo_pairs

We only want pairs where both the the oligos are valid.
We find valid oligo pairs and write their id's into a hash.

=cut
sub validate_oligo_pairs {
    my $self = shift;

    my $design_method = $self->design_param( 'design_method' );
    for my $oligo_pair_region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
        my $oligo_pair_file
            = $self->get_file( $oligo_pair_region . '_oligo_pairs.yaml', $self->oligo_finder_output_dir );

        my $oligo_pairs = LoadFile( $oligo_pair_file );
        DesignCreate::Exception->throw("No oligo pair data in $oligo_pair_file")
            unless $oligo_pairs;

        # store the best oligo pair according to Primer3 ( used as the candidate oligos
        # if none of the oligo pairs for this region turn out to be valid )
        $self->set_region_best_primer3_pair( $oligo_pair_region => $oligo_pairs->[0] );

        my @valid_pairs;
        my $rank = 1;
        for my $pair ( @{ $oligo_pairs } ) {
            next if any{ $self->oligo_is_invalid( $_ ) } values %{ $pair };

            $pair->{primer3_rank} = $rank++;
            push @valid_pairs, $pair;
        }
        next unless @valid_pairs;

        my @sorted_valid_pairs
            = sort { $self->_sort_valid_oligo_pairs($a) <=> $self->_sort_valid_oligo_pairs($b) }
            @valid_pairs;
        ## no critic(BuiltinFunctions::ProhibitComplexMappings)
        $self->validated_oligo_pairs->{$oligo_pair_region}
            = [ map { delete $_->{primer3_rank}; $_ } @sorted_valid_pairs ];
        ## use critic
    }

    return;
}

=head2 _sort_valid_oligo_pairs

Sort the valid oligo pairs, using the Primer3 rank and the combined number of
genomic hits for the 2 oligos in the pair. The lower the number the higher the rank.
Weighted to take into account hits more than primer3 rank. The default setting is
is to discard oligos with any additional genomic hits, so this sort algorithm will
in these cases preserve the Primer3 ranking.

=cut
sub _sort_valid_oligo_pairs {
    my ( $self, $valid_pair ) = @_;
    my %valid_pair = %{ $valid_pair };
    my $primer3_rank = delete $valid_pair{primer3_rank};
    my $oligo_hits = sum map{ $self->bwa_matches->{$_}{hits} } values %valid_pair;

    return ( $primer3_rank / 100 ) + $oligo_hits;
}

=head2 update_candidate_oligos_after_validation

Update design attempt record with the best primer pair from each region.
This means the users will at least have some primers we fail to find a validated
primer pair for each region.

=cut
sub update_candidate_oligos_after_validation {
    my ( $self ) = @_;
    my %candidate_oligo_data;

    my $design_method = $self->design_param( 'design_method' );
    for my $region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
        my $best_pair;
        # if we have a validated primer pair for the region store this
        if ( $self->region_has_oligo_pairs( $region ) ) {
            $best_pair = $self->validated_oligo_pairs->{ $region }[0];
        }
        # else fall back to best pair from Primer3 ( even though one or both
        # of the primers in the pair have failed validation )
        else {
            $best_pair = $self->get_region_best_primer3_pair( $region );
        }
        for my $oligo_type ( keys %{ $best_pair } ) {
            my $oligo = $self->all_oligos->{$oligo_type}{ $best_pair->{$oligo_type} };
            if ( $self->oligo_is_invalid( $oligo->{id} ) ) {
                $oligo->{invalid} = $self->get_invalid_oligo_reason( $oligo->{id} );
            }
            $candidate_oligo_data{ $oligo_type } = $oligo;
        }
    }
    $self->update_design_attempt_record( { candidate_oligos =>  encode_json( \%candidate_oligo_data ) } );

    return;
}

=head2 output_valid_oligo_pairs

Create yaml files storing the valid oligo pairs, one for each region.

=cut
sub output_valid_oligo_pairs {
    my $self = shift;

    my @missing_oligo_pair_regions;
    my $design_method = $self->design_param( 'design_method' );
    for my $oligo_pair_region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
        unless ( $self->region_has_oligo_pairs( $oligo_pair_region ) ) {
            push @missing_oligo_pair_regions, $oligo_pair_region;
            next;
        }

        my $filename = $self->validated_oligo_dir->stringify . '/'
                     . $oligo_pair_region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_valid_pairs( $oligo_pair_region ) );
    }

    if ( @missing_oligo_pair_regions ) {
        DesignCreate::Exception::OligoPairRegionValidation->throw(
            oligo_regions   => \@missing_oligo_pair_regions,
            invalid_reasons => $self->invalid_oligos,
        );
    }

    return;
}

=head2 check_oligo_specificity

Filter out oligos that have mulitple hits against the reference genome.
A unique alignment ( score of 30+ ) gives a true return value. This should be
the case where bwa finds one unique alignment for the oligo, which should be the
original position of the oligo, though this is not checked.

If the oligo can not be mapped against the genome we return false.

In any other case we count the number of hits, which is 90%+ similarity or up to 2 mismatches.
By default any more than 1 hit will return false, the user can loosen this criteria though
and allow up to n hits ( num_genomic_hits attribute ).

=cut
sub check_oligo_specificity {
    my ( $self, $oligo_id, $match_info, $invalid_reason ) = @_;
    # if we have no match info then fail oligo
    return unless $match_info;

    if ( exists $match_info->{unmapped} && $match_info->{unmapped} == 1 ) {
        $self->log->error( "Oligo $oligo_id does not have any alignments, is not mapped to genome" );
        $$invalid_reason = 'Unmapped against genome';
        return;
    }

    #TODO implement three_prime_align checks sp12 Mon 07 Oct 2013 11:14:29 BST
    if ( $self->oligo_three_prime_align ) {
        DesignCreate::Exception->throw("Three prime align checks not implemented yet");

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

    if ( exists $match_info->{unique_alignment} && $match_info->{unique_alignment} ) {
        $self->log->trace( "Oligo $oligo_id has a unique alignment");
        return 1;
    }

    DesignCreate::Exception->throw("No hits value for oligo $oligo_id, can not validate specificity")
        unless exists $match_info->{hits};
    my $hits = $match_info->{hits};

    if ( $hits <= $self->num_genomic_hits ) {
        $self->log->trace( "Oligo $oligo_id has $hits hits, user allowed " . $self->num_genomic_hits );
        return 1;
    }
    else {
        $self->log->debug( "Oligo $oligo_id is invalid, has multiple hits: $hits" );
        $$invalid_reason = "Multiple genomic hits: $hits";
        return;
    }

    return;
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

    # all_oligos defined in DesignCreate::Role::FilterOligos
    for my $oligo_type ( keys %{ $self->all_oligos } ) {
        for my $oligo ( values %{ $self->all_oligos->{$oligo_type} } ) {
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
