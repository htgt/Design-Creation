package DesignCreate::Action::PersistDesign;

=head1 NAME

DesignCreate::Action::PersistDesign - Persist a design to LIMS2

=head1 DESCRIPTION

Persist the design data held in a yaml file to LIMS2.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use LIMS2::REST::Client;
use Try::Tiny;
use YAML::Any;
use Data::Dumper;
use namespace::autoclean;

extends qw( DesignCreate::Action );

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
    isa           => 'Path::Class::File',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    required      => 1,
    documentation => 'The yaml file containing all the design data',
    cmd_flag      => 'design-data'
);

has design_data => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_design_data {
    my $self = shift;

    return YAML::Any::LoadFile( $self->design_data_file );
}

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->log->info('Persisting design to LIMS2');
        $self->log->debug( Dumper( $self->design_data ) );
        $self->lims2_api->POST( 'design', $self->design_data );
    }
    catch {
        $self->log->error('Unable to persist design to LIMS2: ' . $_ );
    };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

