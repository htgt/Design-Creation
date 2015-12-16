package DesignCreate::Cmd::Complete;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Complete::VERSION = '0.039';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Complete

=head1 DESCRIPTION

Base class for all complete design create commands,
These are commands that merge together multiple steps to create a design

=cut

use Moose;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Try::Tiny;
use Scalar::Util 'blessed';
use Data::Dump qw( pp );
use Fcntl; # O_ constants
use JSON;
use YAML::Any qw( DumpFile );
use namespace::autoclean;

extends qw( DesignCreate::Cmd );
with qw( DesignCreate::Role::Common );

has persist => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist design to LIMS2 or WGE',
    default       => 0
);

has design_fail_file => (
    is         => 'ro',
    isa        => AbsFile,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_design_fail_file {
    my $self = shift;

    my $file = $self->dir->file( 'fail.yaml' );
    #create file if it does not exist
    $file->touch unless $self->dir->contains( $file );

    return $file->absolute;
}

#design attempt id, only needed by complete design commands
has da_id => (
    is            => 'rw',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'ID of the associated design attempt',
    cmd_flag      => 'da-id',
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
        # calls the code from the child classes execute subroutine
        inner();
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );

        $self->update_design_attempt_record(
            {
                status     => 'success',
                design_ids => $self->design_ids,
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

=head2 create_design_attempt_record

Create a new design attempt record
Only called if a da_id has not already been set and we are persisting data.

=cut
sub create_design_attempt_record {
    my ( $self, $cmd_opts ) = @_;
    return if !$self->persist;

    $cmd_opts->{'command-name'} = $self->command_names;
    if ( $self->da_id ) {
        $self->update_design_attempt_record( { status => 'started' } );
    }
    else {
        my $da_data = {
            gene_id           => join( ' ', @{ $self->design_param( 'target_genes' ) } ),
            status            => 'started',
            created_by        => $self->design_param( 'created_by' ),
            species           => $self->design_param( 'species' ),
            design_parameters => encode_json( $cmd_opts ),
        };

        try{
            my $design_attempt = $self->lims2_api->POST( 'design_attempt', $da_data );
            $self->da_id( $design_attempt->{id} );
        }
        catch {
            DesignCreate::Exception->throw( "Error creating design attempt record: $_" );
        };
    }

    return;
}

=head2 update_design_attempt_record

Update the associated design_attempt record to latest status.
Only called if persist flag is set.

=cut
sub update_design_attempt_record {
    my ( $self, $data ) = @_;
    return if !$self->persist;

    $data->{id} = $self->da_id;
    try{
        my $design_attempt = $self->lims2_api->PUT( 'design_attempt', $data );
    }
    catch {
        $self->log->error( "Error updating design attempt record: $_" );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
