package DesignCreate::Cmd::Complete::ShortenArmDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Complete::ShortenArmDesign::VERSION = '0.044';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Complete::ShortenArmDesign - Create a new design with shortened arms from a existing design

=head1 DESCRIPTION

Runs all the seperate steps used to create a short arm design.
This is merger of the U and D oligos from a existing design with
new G oligos that shorten arm lengths of the design.

=cut

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Complete );
with qw(
DesignCreate::CmdRole::TargetCurrentDesign
DesignCreate::CmdRole::OligoRegionsGlobalOnly
DesignCreate::CmdRole::FetchOligoRegionsSequence
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateShortenArmDesignData
DesignCreate::CmdRole::PersistDesign
);

# execute in the parent class carries out all the common steps needed for all
# the 'complete' design commands. It calls inner which calls the code below, which
# is where all the code specific to this command is found.
augment 'execute' => sub {
    my ( $self, $opts, $args ) = @_;

    Log::Log4perl::NDC->push( $self->original_design_id );
    # target start / end is the boundary of the U / D oligos
    # of a current design
    $self->target_coordinates;
    # get coordiantes for search regions for global oligos
    $self->get_oligo_region_coordinates;
    $self->create_oligo_region_sequence_files;
    $self->find_oligos;
    $self->filter_oligos;
    $self->pick_gap_oligos;
    # using G oligos we found and U / D oligos from original design
    $self->consolidate_design_data;

    return;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
