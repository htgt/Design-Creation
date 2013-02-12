package DesignCreate::CmdRole::PersistDesign;

=head1 NAME

DesignCreate::CmdRole::PersistDesign - Persist a design to LIMS2

=head1 DESCRIPTION

Persist the design data held in a yaml file to LIMS2.

=cut

use Moose::Role;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use LIMS2::REST::Client;
use Try::Tiny;
use YAML::Any;
use Data::Dump qw( pp );
use namespace::autoclean;

has lims2_api => (
    is         => 'ro',
    isa        => 'LIMS2::REST::Client',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1
);

sub _build_lims2_api {
    my $self = shift;

    return LIMS2::REST::Client->new_with_config();
}

has design_data_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    lazy_build    => 1,
    documentation => 'The yaml file containing all the design data',
    cmd_flag      => 'design-data'
);

#TODO don't code done the file name here
sub _build_design_data_file {
    my $self = shift;

    my $file = $self->dir->file( 'design_data.yaml' );

    return $file->absolute;
}

has design_data => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

#TODO validate we have all oligos required in design data
# rest of the validation should be done on the LIMS2 side

sub _build_design_data {
    my $self = shift;

    return YAML::Any::LoadFile( $self->design_data_file );
}

#TODO return design_id
sub persist_design {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->log->info('Persisting design to LIMS2');
        $self->log->debug( pp( $self->design_data ) );
        $self->lims2_api->POST( 'design', $self->design_data );
    }
    catch {
        $self->log->error('Unable to persist design to LIMS2: ' . $_ );
    };
}

1;

__END__

