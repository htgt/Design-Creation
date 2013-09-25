package DesignCreate::Role::OligoRegionCoordinates;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::OligoRegionCoordinates::VERSION = '0.011';
}
## use critic


=head1 NAME

DesignCreate::Role::OligoRegionCoordinates

=head1 DESCRIPTION

Common code for oligo target ( candidate ) region coordinate finding commands.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Types qw( Species );
use DesignCreate::Constants qw( $DEFAULT_OLIGO_COORD_FILE_NAME %CURRENT_ASSEMBLY );
use YAML::Any qw( DumpFile );
use namespace::autoclean;

has target_genes => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt' ],
    documentation => 'Name of target gene(s) of design',
    required      => 1,
    cmd_flag      => 'target-gene',
);

has oligo_region_coordinates => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {} },
);

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target ( Mouse or Human )',
    required      => 1,
);

has assembly => (
    is         => 'ro',
    isa        => 'Str',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_assembly {
    my $self = shift;

    return $CURRENT_ASSEMBLY{ $self->species };
}

sub create_oligo_region_coordinate_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( $DEFAULT_OLIGO_COORD_FILE_NAME );
    DumpFile( $file, $self->oligo_region_coordinates );

    return;
}

sub get_oligo_region_offset {
    my ( $self, $oligo ) = @_;

    my $attribute_name = 'region_offset_' . $oligo;
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

sub get_oligo_region_length {
    my ( $self, $oligo ) = @_;

    my $attribute_name = 'region_length_' . $oligo;
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

1;

__END__
