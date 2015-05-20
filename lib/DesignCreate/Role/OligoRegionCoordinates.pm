package DesignCreate::Role::OligoRegionCoordinates;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::OligoRegionCoordinates::VERSION = '0.037';
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
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Constants qw(
    $DEFAULT_OLIGO_COORD_FILE_NAME
    $DEFAULT_TARGET_COORD_FILE_NAME
);
use YAML::Any qw( DumpFile LoadFile );
use JSON;
use namespace::autoclean;

has target_coordinate_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    documentation => 'File containing target coordinates ( default '
                     . "[design_dir]/oligo_target_regions/$DEFAULT_TARGET_COORD_FILE_NAME )",
    cmd_flag      => 'target-coord-file',
    coerce        => 1,
    lazy_build    => 1,
);

sub _build_target_coordinate_file {
    my $self = shift;

    return $self->get_file( $DEFAULT_TARGET_COORD_FILE_NAME, $self->oligo_target_regions_dir );
}

has target_data => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        get_target_data  => 'get',
        have_target_data => 'exists',
    }
);

sub _build_target_data {
    my $self = shift;

    return LoadFile( $self->target_coordinate_file );
}

has oligo_region_coordinates => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {} },
);


sub create_oligo_region_coordinate_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( $DEFAULT_OLIGO_COORD_FILE_NAME );
    DumpFile( $file, $self->oligo_region_coordinates );

    return;
}

sub set_design_attempt_candidate_regions {
    my $self = shift;

    my %candidate_regions = %{ $self->oligo_region_coordinates };
    my $chr_name = $self->design_param( 'chr_name' );
    $candidate_regions{$_}{chromosome} = $chr_name for keys %candidate_regions;
    $self->update_design_attempt_record(
        { candidate_regions => encode_json( $self->oligo_region_coordinates ) } );

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

=head2 check_oligo_region_sizes

Check size of region we search for oligos in is big enough

=cut
sub check_oligo_region_sizes {
    my ( $self ) = @_;

    for my $oligo_type ( $self->expected_oligos ) {
        my $length_attr =  'region_length_' . $oligo_type;
        my $length = $self->$length_attr;

        # currently 22 is the smallest oligo we allow from primer
        DesignCreate::Exception->throw( "$oligo_type region too small: $length" )
            if $length < 22;
    }

    return;
}

1;

__END__
