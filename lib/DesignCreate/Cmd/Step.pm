package DesignCreate::Cmd::Step;

=head1 NAME

DesignCreate::Cmd::Step

=head1 DESCRIPTION

Base class for all the individual step design create commands,
These are commands that are one stage in the whole design creation process.
Multiple steps are stringed together to create a design.

=cut

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Cmd );
with qw(
DesignCreate::Role::CmdStep
);

#TODO custom code? sp12 Tue 11 Mar 2014 10:53:29 GMT

__PACKAGE__->meta->make_immutable;

1;

__END__
