package DesignCreate::Role::EnsEMBL;

=head1 NAME

DesignCreate::Role::EnsEMBL

=head1 DESCRIPTION

This role can grab sequence from EnsEMBL.

=cut

use Moose::Role;
use DesignCreate::Exception;
use Try::Tiny;
use namespace::autoclean;

has ensembl_util => (
    is         => 'ro',
    isa        => 'LIMS2::Util::EnsEMBL',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
    handles    => [ qw( slice_adaptor exon_adaptor ) ],
);

sub _build_ensembl_util {
    my $self = shift;
    require LIMS2::Util::EnsEMBL;

    my $species = $self->design_param( 'species' );
    return LIMS2::Util::EnsEMBL->new( species => $species );
}

sub get_sequence {
    my ( $self, $start, $end, $chr_name ) = @_;

    my $slice = $self->_get_sequence( $start, $end, $chr_name );

    return $slice->seq;
}

sub get_repeat_masked_sequence {
    my ( $self, $start, $end, $chr_name ) = @_;

    my $slice = $self->_get_sequence( $start, $end, $chr_name );

    # softmasked
    my $repeat_masked_slice = $slice->get_repeatmasked_seq( undef , 1 );

    return $repeat_masked_slice->seq;
}

sub _get_sequence {
    my ( $self, $start, $end, $chr_name ) = @_;
    my $slice;
    $chr_name //= $self->chr_name;

    $self->log->logdie( 'Start must be less than end' )
        if $start > $end;

    # We always get sequence on the +ve strand
    try{
        $slice = $self->slice_adaptor->fetch_by_region(
            'chromosome',
            $chr_name,
            $start,
            $end,
        );
    }
    catch{
        DesignCreate::Exception->throw( 'Error fetching Ensembl slice: ' . $_ );
    };

    return $slice;
}

1;

__END__
