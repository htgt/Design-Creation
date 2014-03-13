package DesignCreate::Cmd::Complete;

=head1 NAME

DesignCreate::Cmd::Complete

=head1 DESCRIPTION

Base class for all complete design create commands,
These are commands that merge together multiple steps to create a design

=cut

use Moose;
use Try::Tiny;
use Scalar::Util 'blessed';
use Data::Dump qw( pp );
use Fcntl; # O_ constants
use JSON;
use YAML::Any qw( DumpFile );
use namespace::autoclean;

extends qw( DesignCreate::Cmd );
with qw(
DesignCreate::Role::CmdComplete
);

has persist => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist design to LIMS2 or WGE',
    default       => 0
);

# this execute carries out all the common steps needed for the 'complete' design commands,
# which are sub-classes of this class.
# We call inner here which calls the sub class specific code, which is found in the
# execute subroutines in the sub-classes.
sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );

    $self->log->info( 'Starting new design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );
    $self->create_design_attempt_record( $opts );

    try{
        inner();
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );

        $self->update_design_attempt_record(
            {
                status     => 'success',
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
