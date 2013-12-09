package DesignCreate::CmdRole::PersistDesign;

=head1 NAME

DesignCreate::CmdRole::PersistDesign - Persist a design to LIMS2

=head1 DESCRIPTION

Persist the design data held in a yaml file to LIMS2.

=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Try::Tiny;
use YAML::Any;
use Data::Dump qw( pp );
use namespace::autoclean;

has design_data_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    lazy_build    => 1,
    documentation => 'The yaml file containing design data ( default [work_dir]/design_data.yaml )',
    cmd_flag      => 'design-data-file'
);

sub _build_design_data_file {
    my $self = shift;

    my $file = $self->dir->file( $self->design_data_file_name );

    return $file->absolute;
}

has alternate_designs_data_file => (
    is            => 'rw',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    predicate     => 'have_alt_designs_file',
    coerce        => 1,
    documentation => 'The yaml file containing alternate designs data ( default [work_dir]/alt_designs.yaml )',
    cmd_flag      => 'alt-designs-data-file'
);

has alternate_designs => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist alternate design to LIMS2',
    cmd_flag      => 'alt-designs',
    default       => 0
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

has alternate_designs_data => (
    is         => 'ro',
    isa        => 'ArrayRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_alternate_designs_data {
    my $self = shift;

    return YAML::Any::LoadFile( $self->alternate_designs_data_file );
}

has design_ids => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [ 'NoGetopt' ],
    default => sub{ [] },
);

sub persist_design {
    my ( $self, $opts, $args ) = @_;

    $self->log->info('Persisting design to LIMS2 for gene(s): '
                     . join( ',', @{ $self->design_data->{gene_ids} } ) );

    $self->_persist_design( $self->design_data );

    return unless $self->alternate_designs;
    $self->set_alternate_designs_data_file;
    unless ( $self->have_alt_designs_file ) {
        $self->log->warn( 'No alternate designs to persist' );
        return;
    }

    $self->log->info('Persisting alternate design to LIMS2');
    for my $alt_design_data ( @{ $self->alternate_designs_data } ) {
        $self->_persist_design( $alt_design_data );
    }
    return;
}

sub _persist_design {
    my ( $self, $design_data ) = @_;

    try{
        $self->log->debug( pp( $design_data ) );
        my $design = $self->lims2_api->POST( 'design', $design_data );
        $self->log->info('Design persisted: ' . $design->{id} );
        push @{ $self->design_ids }, $design->{id};
    }
    catch {
        DesignCreate::Exception->throw( 'Unable to persist design to LIMS2: ' . $_ );
    };
    return;
}

sub set_alternate_designs_data_file {
    my $self = shift;
    return if $self->have_alt_designs_file;

    #default file
    my $alt_designs_file = $self->dir->file( $self->alt_designs_data_file_name );
    return unless $self->dir->contains( $alt_designs_file );

    $self->alternate_designs_data_file( $alt_designs_file->absolute );
    return;
}

1;

__END__
