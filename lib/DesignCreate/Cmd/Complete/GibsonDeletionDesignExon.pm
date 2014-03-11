package DesignCreate::Cmd::Complete::GibsonDeletionDesignExon;

=head1 NAME

DesignCreate::Cmd::Complete::GibsonDeletionDesignExon - Run design creation for gibson deletion design on exon(s)

=head1 DESCRIPTION

Runs all the seperate steps used to create a gibson deletion design on specified exon(s).
Persists the design to LIMS2 if persist option given.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );
use Scalar::Util 'blessed';
use JSON;
use YAML::Any qw( DumpFile );

extends qw( DesignCreate::Cmd::Complete );
with qw(
DesignCreate::CmdRole::TargetExons
DesignCreate::CmdRole::OligoPairRegionsGibsonDel
DesignCreate::CmdRole::FindGibsonOligos
DesignCreate::CmdRole::FilterGibsonOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );
    my $exon_string = $self->five_prime_exon;
    $exon_string .= '-' . $self->three_prime_exon if $self->three_prime_exon;
    Log::Log4perl::NDC->push( $exon_string );

    $self->log->info( 'Starting new gibson deletion design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );
    $self->create_design_attempt_record( $opts );

    try {
        $self->target_coordinates;
        $self->get_oligo_pair_region_coordinates;
        $self->find_oligos;
        $self->filter_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );

        $self->update_design_attempt_record(
            {   status => 'success',
                design_ids => join( ' ', @{ $self->design_ids } ),
            }
        );
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
