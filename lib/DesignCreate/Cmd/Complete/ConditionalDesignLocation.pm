package DesignCreate::Cmd::Complete::ConditionalDesignLocation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Complete::ConditionalDesignLocation::VERSION = '0.030';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Complete::ConditionalDesignLocation - Create a location specified conditional design

=head1 DESCRIPTION

Runs all the seperate steps used to create a conditional design on a custom target.

=cut

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Complete );
with qw(
DesignCreate::CmdRole::TargetLocation
DesignCreate::CmdRole::OligoRegionsConditional
DesignCreate::CmdRole::FetchOligoRegionsSequence
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickBlockOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

# execute in the parent class carries out all the common steps needed for all
# the 'complete' design commands. It calls inner which calls the code below, which
# is where all the code specific to this command is found.
augment 'execute' => sub {
    my ( $self, $opts, $args ) = @_;

    $self->target_coordinates;
    $self->get_oligo_region_coordinates;
    $self->create_oligo_region_sequence_files;
    $self->find_oligos;
    $self->filter_oligos;
    $self->pick_gap_oligos;
    $self->pick_block_oligos;
    $self->consolidate_design_data;

    return;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
