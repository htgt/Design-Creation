package DesignCreate::Cmd::Complete::DeletionDesignLocation;

=head1 NAME

DesignCreate::Cmd::Complete::DeletionDesignLocation - Create a location specified deletion design

=head1 DESCRIPTION

Runs all the seperate steps used to create a deletion design on a custom target.

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
DesignCreate::CmdRole::OligoRegionsInsDel
DesignCreate::CmdRole::FetchOligoRegionsSequence
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );

    $self->log->info( 'Starting new ins-del design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );
    $self->create_design_attempt_record( $opts );

    try {
        $self->target_coordinates;
        $self->get_oligo_region_coordinates;
        $self->create_oligo_region_sequence_files;
        $self->find_oligos;
        $self->filter_oligos;
        $self->pick_gap_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );
    }
    catch {
        if (blessed($_) and $_->isa('DesignCreate::Exception')) {
            DumpFile( $self->design_fail_file, $_->as_hash );
            $self->update_design_attempt_record(
                {   status => 'fail',
                    fail   => encode_json( $_->as_hash ),
                }
            );
        }
        else {
            $self->update_design_attempt_record(
                {   status => 'error',
                    error => $_,
                }
            );
        }
        $self->log->error( 'DESIGN INCOMPLETE: ' . $_ );
    };

    Log::Log4perl::NDC->remove;
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
