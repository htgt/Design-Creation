package DesignCreate::Action::ConditionalDesign;

=head1 NAME

DesignCreate::Action::ConditionalDesign - Run design creation for condition designs, end to end

=head1 DESCRIPTION

Runs all the seperate steps used to create a conditional design.
Persists the design to LIMS2 if persist option given.

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
DesignCreate::CmdRole::OligoRegionsConditional
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickBlockOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

has persist => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist design to LIMS2',
    default       => 0
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
genomic_search_method
);

for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
}

has '+design_method' => (
    traits => [ 'NoGetopt' ],
    default => 'conditional',
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->log->info( 'Starting new design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );

    try {
        $self->build_oligo_target_regions;
        $self->find_oligos;
        $self->filter_oligos;
        $self->pick_gap_oligos;
        $self->pick_block_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );
    }
    catch {
        $self->log->error( 'DESIGN INCOMPLETE: ' . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
