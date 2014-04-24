package DesignCreate::Role::Common;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::Common::VERSION = '0.025';
}
## use critic


=head1 NAME

DesignCreate::Role::Common

=head1 DESCRIPTION

Role consumed by DesignCreate::Cmd::Step and DesignCreate::Cmd::Complete, the base classes
for all the design create commands.
These attributes / methods are stored here so they can also be applied to a seperate
test base class, this enables unit testing of all the design create commands. Otherwise it
is not possible to instantiate the DesignCreate command modules outside of the command line.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Constants qw(
    $DEFAULT_VALIDATED_OLIGO_DIR_NAME
    $DEFAULT_OLIGO_FINDER_OUTPUT_DIR_NAME
    $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME
    $DEFAULT_DESIGN_DATA_FILE_NAME
    $DEFAULT_ALT_DESIGN_DATA_FILE_NAME
);
use LIMS2::REST::Client;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir AbsFile/;
use YAML::Any qw( LoadFile DumpFile );
use Const::Fast;
use Try::Tiny;
use JSON;
use namespace::autoclean;

has design_parameters => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        get_design_param => 'get',
        set_param        => 'set',
        param_exists     => 'exists',
    }
);

sub _build_design_parameters {
    my $self = shift;

    my $params = LoadFile( $self->design_parameters_file );
    return $params ? $params : {};
}

has design_parameters_file => (
    is         => 'ro',
    isa        => AbsFile,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_design_parameters_file {
    my $self = shift;

    my $file = $self->dir->file( 'design_parameters.yaml' );
    #create file if it does not exist
    $file->touch unless $self->dir->contains( $file );

    return $file->absolute;
}

has oligos => (
    is         => 'ro',
    isa        => 'ArrayRef',
    traits     => [ 'NoGetopt', 'Array' ],
    lazy_build => 1,
    handles     => {
        expected_oligos => 'elements'
    }
);

## no critic(ProhibitCascadingIfElse)
sub _build_oligos {
    my $self = shift;

    my $design_method = $self->design_param( 'design_method' );
    if ( $design_method eq 'deletion' || $design_method eq 'insertion' ) {
        return [ qw( G5 U5 D3 G3 ) ];
    }
    elsif ( $design_method eq 'conditional' ) {
        return [ qw( G5 U5 U3 D5 D3 G3 ) ];
    }
    elsif ( $design_method eq 'gibson' ) {
        return [ qw( 5F 5R EF ER 3F 3R ) ];
    }
    elsif ( $design_method eq 'gibson-deletion' ) {
        return [ qw( 5F 5R 3F 3R ) ];
    }
    else {
        DesignCreate::Exception->throw( 'Unknown design method ' . $design_method );
    }

    return;
}
## use critic

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

#
# Directories common to multiple commands
#

has design_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => $DEFAULT_DESIGN_DATA_FILE_NAME,
   traits  => [ 'NoGetopt' ],
);

has alt_designs_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => $DEFAULT_ALT_DESIGN_DATA_FILE_NAME,
   traits  => [ 'NoGetopt' ],
);

has dir => (
    is            => 'ro',
    isa           => AbsDir,
    traits        => [ 'Getopt' ],
    documentation => 'The working directory for this design',
    required      => 1,
    coerce        => 1,
    trigger       => \&_init_output_dir
);

sub _init_output_dir {
    my ( $self, $dir ) = @_;

    # create the dir if it does not exist
    $dir->mkpath();
    return;
}

has validated_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'NoGetopt' ],
    lazy_build    => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME )->absolute;
    $validated_oligo_dir->mkpath();

    return $validated_oligo_dir;
}

has oligo_finder_output_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'NoGetopt' ],
    lazy_build    => 1,
);

sub _build_oligo_finder_output_dir {
    my $self = shift;

    my $oligo_finder_output_dir = $self->dir->subdir( $DEFAULT_OLIGO_FINDER_OUTPUT_DIR_NAME )->absolute;
    $oligo_finder_output_dir->mkpath();

    return $oligo_finder_output_dir;
}

has oligo_target_regions_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'NoGetopt' ],
    lazy_build    => 1,
);

sub _build_oligo_target_regions_dir {
    my $self = shift;

        my $oligo_target_regions_dir = $self->dir->subdir( $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME )->absolute;
    $oligo_target_regions_dir->mkpath();

    return $oligo_target_regions_dir;
}

sub get_file {
    my ( $self, $filename, $dir ) = @_;

    my $file = $dir->file( $filename );
    DesignCreate::Exception::MissingFile->throw( file => $file, dir => $dir )
        unless $dir->contains( $file );

    return $file;
}

# add values to the design parameters hash and dump into the design_parameters.yaml file
sub add_design_parameters {
    my( $self, $attributes ) = @_;

    for my $attribute ( @{ $attributes } ) {
        DesignCreate::Exception::NonExistantAttribute->throw(
            attribute_name => $attribute,
            class          => $self->meta->name
        ) unless $self->meta->has_attribute($attribute);

        $self->set_param( $attribute, $self->$attribute );
    }

    DumpFile( $self->design_parameters_file, $self->design_parameters );
    return;
}

# get design parameter stored in design_parameters.yaml file
# if it can't find it look for a attribute with the same name
sub design_param {
    my ( $self, $param_name ) = @_;

    unless ( $self->param_exists( $param_name ) ) {
        if ( $self->meta->has_attribute( $param_name ) ) {
            return $self->$param_name
        }
        else {
            DesignCreate::Exception->throw("$param_name not stored in design parameters hash or attribute value")
        }
    }

    return $self->get_design_param( $param_name );
}

1;

__END__
