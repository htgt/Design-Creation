package DesignCreate::Action::Run;

=head1 NAME

DesignCreate::Action::Run - Run design creation end to end

=head1 DESCRIPTION

Runs all the seperate steps used to create a design.

=cut

#
# Initial version will be setup for standard deletion design only
#

use strict;
use Fcntl; # O_ constants
use warnings FATAL => 'all';

use Moose;

extends qw( DesignCreate::Action );
with qw(
DesignCreate::CmdRole::OligoTargetRegions
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->build_oligo_target_regions;
    $self->find_oligos;
    $self->filter_oligos;
    $self->pick_gap_oligos;
    $self->consolidate_design_data;
    $self->persist_design;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
