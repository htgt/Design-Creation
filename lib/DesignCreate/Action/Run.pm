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
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );
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

# Turn off the following attributes command line option attribute
# these values should be set when running the design creation process
# end to end
const my @ATTRIBUTES_NO_CMD_OPTION => qw(
target_file
exonerate_target_file
design_data_file
validated_oligo_dir
aos_output_dir
oligo_target_regions_dir
aos_location
base_chromosome_dir
);

for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
}

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->log->info( 'Starting new design create run' );
    $self->log->debug( 'Design run args: ' . pp($opts) );

    try {
        $self->build_oligo_target_regions;
        $self->find_oligos;
        $self->filter_oligos;
        $self->pick_gap_oligos;
        $self->consolidate_design_data;
        #$self->persist_design;
    }
    catch {
        $self->log->error( 'Error completing design creation run: ' . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
