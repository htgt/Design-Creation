package DesignCreate::Action::ConditionalDesignLocation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::ConditionalDesignLocation::VERSION = '0.021';
}
## use critic


=head1 NAME

DesignCreate::Action::ConditionalDesignLocation - Run design creation for location specified condition designs, end to end

=head1 DESCRIPTION

Runs all the seperate steps used to create a location specified conditional design.
Persists the design to LIMS2 if persist option given.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );


extends qw( DesignCreate::Action );
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
oligo_finder_output_dir
oligo_target_regions_dir
aos_location
base_chromosome_dir
genomic_search_method
);

for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
}

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );

    $self->log->info( 'Starting new design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );

    try {
        $self->target_coordinates;
        $self->get_oligo_region_coordinates;
        $self->create_oligo_region_sequence_files;
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

    Log::Log4perl::NDC->remove;
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
