package DesignCreate::Role::EnsEMBL;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::EnsEMBL::VERSION = '0.008';
}
## use critic


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

# mask_method is a array_ref of repeat classes,
# WARNING: if this array_ref is empty then nothing will get masked.
sub get_repeat_masked_sequence {
    my ( $self, $start, $end, $chr_name, $mask_method ) = @_;

    my $slice = $self->_get_sequence( $start, $end, $chr_name );

    # softmasked
    my $repeat_masked_slice = $slice->get_repeatmasked_seq( $mask_method , 1 );

    return $repeat_masked_slice->seq;
}

sub _get_sequence {
    my ( $self, $start, $end, $chr_name, $try_count ) = @_;
    $try_count //= 1;
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
        if ( $try_count < 5 ) {
            $self->log->debug( "Error fetching Ensembl slice on try $try_count: " . $_ );
            $self->_reset_ensembl_connection( $try_count );
            $self->_get_sequence( $start, $end, $chr_name, ++$try_count );
        }
        else {
            DesignCreate::Exception->throw( 'Error fetching Ensembl slice: ' . $_ );
        }
    };

    # for some reason we can either fail to get a slice or there is trouble getting the sequence
    # from the slice, so i am adding this check in here
    try {
        $slice->seq;
    }
    catch {
        DesignCreate::Exception->throw( "Unable to fetch Ensembl slice $_" ) if $try_count >= 5;
        $self->log->debug( "Error fetching Ensembl slice sequence or try $try_count: " . $_ );
        $self->_reset_ensembl_connection( $try_count );
        $self->_get_sequence( $start, $end, $chr_name, ++$try_count );
    };

    return $slice;
}

sub _reset_ensembl_connection {
    my ( $self, $try_count ) = @_;

    $self->log->debug( "Clearing registry attribute" );
    $self->ensembl_util->clear_registry;

    $self->log->debug( "Deleting ensembl_util attribute" );
    $self->clear_ensembl_util;

    sleep( $try_count * 3 );
    return;
}

1;

__END__
