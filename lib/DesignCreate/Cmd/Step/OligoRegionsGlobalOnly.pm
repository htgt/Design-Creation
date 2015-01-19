package DesignCreate::Cmd::Step::OligoRegionsGlobalOnly;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::OligoRegionsGlobalOnly::VERSION = '0.033';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::OligoRegionsGlobalOnly - Get coordiantes for global oligo target regions

=head1 DESCRIPTION

For given target coordinates and oligo region parameters produce target region coordinates file
for the global oligos.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::OligoRegionsGlobalOnly';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->get_oligo_region_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate oligo target region coordinates:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
