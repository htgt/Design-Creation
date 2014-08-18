package DesignCreate::Cmd::Complete::GibsonDesignExon;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Complete::GibsonDesignExon::VERSION = '0.028';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Complete::GibsonDesignExon - Create a conditional gibson design for exon targets

=head1 DESCRIPTION

Runs all the seperate steps used to create a conditional gibson design on a specified exon(s).

=cut

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Complete );
with qw(
DesignCreate::CmdRole::TargetExons
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
