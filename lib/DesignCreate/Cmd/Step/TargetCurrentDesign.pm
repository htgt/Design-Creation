package DesignCreate::Cmd::Step::TargetCurrentDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::TargetCurrentDesign::VERSION = '0.040';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::TargetCurrentDesign - Work out target region coordiantes of current LIMS2 design

=head1 DESCRIPTION

Generate a yaml file giving coordinates of the target region of a current LIMS2 design
by using its U5 and D3 oligo locations.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::TargetCurrentDesign';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->target_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate target coordinates:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
