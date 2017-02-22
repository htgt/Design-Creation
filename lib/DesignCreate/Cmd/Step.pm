package DesignCreate::Cmd::Step;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::VERSION = '0.045';
}
## use critic


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
with qw( DesignCreate::Role::Common );

has '+is_step' => (
    default => 1,
);

=head2 update_design_attempt_record

For step commands we do not update design attempt data

=cut
sub update_design_attempt_record {
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
