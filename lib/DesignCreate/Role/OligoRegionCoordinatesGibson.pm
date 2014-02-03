package DesignCreate::Role::OligoRegionCoordinatesGibson;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::OligoRegionCoordinatesGibson::VERSION = '0.018';
}
## use critic


=head1 NAME

DesignCreate::Role::OligoRegionCoordinatesGibson

=head1 DESCRIPTION

Common code for finding oligo region coordinates for gibson designs.

=cut

use Moose::Role;
use DesignCreate::Exception;
use Try::Tiny;
use namespace::autoclean;

=head2 calculate_target_region_coordinates

Calculate following values given the target exon(s):
target_start
target_end
chr_strand
chr_name

=cut
sub calculate_target_region_coordinates {
    my $self = shift;

    my $five_prime_exon = $self->build_exon( $self->five_prime_exon );
    $self->chr_name( $five_prime_exon->seq_region_name ) unless $self->chr_name;
    $self->chr_strand( $five_prime_exon->strand ) unless $self->chr_strand;

    my $three_prime_exon
        = $self->three_prime_exon ? $self->build_exon( $self->three_prime_exon ) : undef;

    # if there is no three prime exon then just specify target start and end
    # as the start and end of the five prime exon
    unless ( $three_prime_exon ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
        return;
    }

    $self->validate_exon_targets( $five_prime_exon, $three_prime_exon );

    if ( $self->chr_strand == 1 ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $three_prime_exon->seq_region_end );
    }
    else {
        $self->target_start( $three_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
    }

    return;
}

=head2 validate_exon_targets

Check exons are both on the same gene.
Check the five prime exon is before the three prime exon.

=cut
sub validate_exon_targets {
    my ( $self, $five_prime_exon, $three_prime_exon ) = @_;

    my $five_prime_exon_gene  = $self->gene_adaptor->fetch_by_exon_stable_id( $five_prime_exon->stable_id );
    my $three_prime_exon_gene = $self->gene_adaptor->fetch_by_exon_stable_id( $three_prime_exon->stable_id );

    DesignCreate::Exception->throw(
        'Exon mismatch,'
        . ' five prime exon '      . $five_prime_exon->stable_id
        . ' is linked to gene '    . $five_prime_exon_gene->stable_id
        . ' BUT three prime exon ' . $three_prime_exon->stable_id
        . ' is linked to gene  '   . $three_prime_exon_gene->stable_id
    ) if $five_prime_exon_gene->stable_id ne $three_prime_exon_gene->stable_id;

    if ( $self->chr_strand == 1 ) {
        DesignCreate::Exception->throw(
            'On +ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is after the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start > $three_prime_exon->seq_region_start;
    }
    else {
        DesignCreate::Exception->throw(
            'On -ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is before the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start < $three_prime_exon->seq_region_start;
    }

    return;
}

=head2 build_exon

Grab a Bio::Ensembl::Exon object given a exon stable id.
Make sure exon object is in teh chromosome coordinate system.

=cut
sub build_exon {
    my ( $self, $exon_id ) = @_;
    my $exon;

    try{
        $exon = $self->exon_adaptor->fetch_by_stable_id( $exon_id );
    };

    unless ( $exon ) {
        DesignCreate::Exception->throw(
            'Unable to retrieve exon: ' . $exon_id );
    }

    # check exon is on the chromosome coordinate system
    if ( $exon->coord_system_name ne 'chromosome' ) {
        $exon = $exon->transform( 'chromosome' );
    }

    return $exon;
}

=head2 check_oligo_region_sizes

Check size of region we search for oligos in is big enough

=cut
sub check_oligo_region_sizes {
    my ( $self ) = @_;

    for my $oligo_type ( $self->expected_oligos ) {
        my $length_attr =  'region_length_' . $oligo_type;
        my $length = $self->$length_attr;

        # currently 22 is the smallest oligo we allow from primer
        DesignCreate::Exception->throw( "$oligo_type region too small: $length" )
            if $length < 22;
    }

    return;
}

1;

__END__
