package DesignCreate::Cmd::Complete::GibsonDesignLocation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Complete::GibsonDesignLocation::VERSION = '0.023';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Complete::GibsonDesignLocation - Create a location specified gibson design

=head1 DESCRIPTION

Runs all the seperate steps used to create a gibson design on a custom target.

=cut

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Complete );
with qw(
DesignCreate::CmdRole::TargetLocation
DesignCreate::CmdRole::OligoPairRegionsGibson
DesignCreate::CmdRole::FindGibsonOligos
DesignCreate::CmdRole::FilterGibsonOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

# execute in the parent class carries out all the common steps needed for all
# the 'complete' design commands. It calls inner which calls the code below, which
# is where all the code specific to this command is found.
augment 'execute' => sub {
    my ( $self, $opts, $args ) = @_;

    $self->target_coordinates;
    $self->get_oligo_pair_region_coordinates;
    $self->find_oligos;
    $self->filter_oligos;
    $self->consolidate_design_data;

    return;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
