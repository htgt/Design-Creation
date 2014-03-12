package DesignCreate::Cmd::Complete::ConditionalDesignLocation;

=head1 NAME

DesignCreate::Cmd::Complete::ConditionalDesignLocation - Create a location specified conditional design

=head1 DESCRIPTION

Runs all the seperate steps used to create a conditional design on a specified custom target.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );

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
