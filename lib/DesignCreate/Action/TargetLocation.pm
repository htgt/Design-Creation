package DesignCreate::Action::TargetLocation;

=head1 NAME

DesignCreate::Action::TargetExons - Work out target region coordiantes

=head1 DESCRIPTION

Generate a yaml file giving coordinates of the target region.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::TargetLocation';

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
