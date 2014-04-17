package DesignCreate::Cmd::Step::PersistDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::PersistDesign::VERSION = '0.024';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::PersistDesign - Persist a design to LIMS2

=head1 DESCRIPTION

Persist the design data held in a yaml file to LIMS2.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::PersistDesign';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->persist_design;
    }
    catch{
        $self->log->error( "Error persisting design to LIMS2:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
