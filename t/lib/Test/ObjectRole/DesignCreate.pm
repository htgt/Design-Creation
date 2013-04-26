package Test::ObjectRole::DesignCreate;

use strict;
use warnings FATAL => 'all';

use Moose;
use DesignCreate::Types qw( DesignMethod ArrayRefOfOligos );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir AbsFile/;
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use YAML::Any qw( LoadFile DumpFile );
use Fcntl; # O_ constants
use namespace::autoclean;

has design_method => (
    is       => 'ro',
    isa      => DesignMethod,
    required => 1,
);

has dir => (
    is  => 'ro',
    isa => 'Path::Class::Dir',
);

has design_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => 'design_data.yaml',
);

has design_parameters => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        get_design_param    => 'get',
        set_param    => 'set',
        param_exists => 'exists',
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
    isa        => ArrayRefOfOligos,
    traits     => [ 'NoGetopt', 'Array' ],
    lazy_build => 1,
    handles => {
        expected_oligos => 'elements'
    }
);

sub _build_oligos {
    my $self = shift;

    if ( $self->design_method eq 'deletion' || $self->design_method eq 'insertion' ) {
        return [ qw( G5 U5 D3 G3 ) ];
    }
    elsif ( $self->design_method eq 'conditional' ) {
        return [ qw( G5 U5 U3 D5 D3 G3 ) ];
    }
    else {
        DesignCreate::Exception->throw( 'Unknown design method ' . $self->design_method );
    }
    return;
}

has alt_designs_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => 'alt_designs.yaml',
);

has validated_oligo_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'validated_oligos' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
}

has aos_output_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_aos_output_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'aos_output' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
}

has oligo_target_regions_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_oligo_target_regions_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'oligo_target_regions' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
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
        my $val = $self->$attribute;
        $self->set_param( $attribute, $self->$attribute );
    }

    DumpFile( $self->design_parameters_file, $self->design_parameters );
    return;
}

# get design parameter stored in design_parameters.yaml file
sub design_param {
    my ( $self, $param_name ) = @_;

    DesignCreate::Exception->throw("$param_name not stored in design parameters hash")
        unless $self->param_exists( $param_name );

    return $self->get_design_param( $param_name );
}

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
);

__PACKAGE__->meta->make_immutable;

1;

__END__
