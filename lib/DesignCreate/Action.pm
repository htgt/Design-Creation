package DesignCreate::Action;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir/;
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use DesignCreate::Types qw( DesignMethod );
use Log::Log4perl qw( :levels );
use Try::Tiny;
use Const::Fast;
use namespace::autoclean;

extends qw( MooseX::App::Cmd::Command );
with qw(
MooseX::Log::Log4perl
);
#TODO use SimpleConfig,
#MooseX::SimpleConfig

has trace => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Enable trace logging',
    default       => 0
);

has debug => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Enable debug logging',
    default       => 0
);

has verbose => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Enable verbose logging',
    default       => 0
);

has design_method => (
    is            => 'ro',
    isa           => DesignMethod,
    traits        => [ 'Getopt' ],
    required      => 1,
    default       => 'deletion',
    documentation => 'Design type, deletion, insertion or conditional ( default deletion )',
    cmd_flag      => 'design-method',
);

#
# Directories common to multiple commands
#

const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME      => 'validated_oligos';
const my $DEFAULT_AOS_OUTPUT_DIR_NAME           => 'aos_output';
const my $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME => 'oligo_target_regions';
const my $DEFAULT_DESIGN_DATA_FILE_NAME         => 'design_data.yaml';

has validated_oligo_dir_name => (
    is      => 'ro',
    isa     => 'Str',
    default => $DEFAULT_VALIDATED_OLIGO_DIR_NAME,
    traits  => [ 'NoGetopt' ],
);

has aos_output_dir_name => (
    is      => 'ro',
    isa     => 'Str',
    default => $DEFAULT_AOS_OUTPUT_DIR_NAME,
    traits  => [ 'NoGetopt' ],
);

has oligo_target_regions_dir_name => (
    is      => 'ro',
    isa     => 'Str',
    default => $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME,
    traits  => [ 'NoGetopt' ],
);

has design_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => $DEFAULT_DESIGN_DATA_FILE_NAME,
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

    $dir->mkpath();
}

has validated_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the validated oligos '
                     . "( default [design_dir]/$DEFAULT_VALIDATED_OLIGO_DIR_NAME )",
    coerce        => 1,
    cmd_flag      => 'validated-oligo-dir',
    lazy_build    => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $self->validated_oligo_dir_name )->absolute;
    $validated_oligo_dir->rmtree();
    $validated_oligo_dir->mkpath();

    return $validated_oligo_dir;
}

has aos_output_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the oligo yaml files '
                     . "( default [design_dir]/$DEFAULT_AOS_OUTPUT_DIR_NAME )",
    coerce        => 1,
    lazy_build    => 1,
    cmd_flag      => 'aos-output-dir',
);

sub _build_aos_output_dir {
    my $self = shift;

    my $aos_output_dir = $self->dir->subdir( $self->aos_output_dir_name )->absolute;
    $aos_output_dir->rmtree();
    $aos_output_dir->mkpath();

    return $aos_output_dir;
}

has oligo_target_regions_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'Getopt' ],
    documentation => 'Directory holding the oligo target region fasta files '
                     . "( default [design_dir]/$DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME )",
    lazy_build => 1,
    cmd_flag      => 'oligo-target-region-dir',
    coerce        => 1,
);

sub _build_oligo_target_regions_dir {
    my $self = shift;

    my $oligo_target_regions_dir = $self->dir->subdir( $self->oligo_target_regions_dir_name )->absolute;
    $oligo_target_regions_dir->rmtree();
    $oligo_target_regions_dir->mkpath();

    return $oligo_target_regions_dir;
}

sub BUILD {
    my $self = shift;

    my $log_level
        = $self->trace   ? $TRACE
        : $self->debug   ? $DEBUG
        : $self->verbose ? $INFO
        :                  $WARN;

    # Log output goes to STDERR and a log file
    Log::Log4perl->easy_init(
        {
            level    => $log_level,
            file     => ">>" . $self->dir . '/design-create.log',
            layout   => '%d %c %p %m%n',
        },
        {
            level    => $log_level,
            file     => "STDERR",
            layout   => '%d %c %p %m%n',
        },
    );

    return;
}

sub get_file {
    my ( $self, $filename, $dir ) = @_;

    my $file = $dir->file( $filename );
    DesignCreate::Exception::MissingFile->throw( file => $file, dir => $dir )
        unless $dir->contains( $file );

    return $file;
}

override command_names => sub {
    # from App::Cmd::Command
    my ( $name ) = (ref( $_[0] ) || $_[0]) =~ /([^:]+)$/;

    # split camel case into words
    my @parts = $name =~ m/[[:upper:]](?:[[:upper:]]+|[[:lower:]]*)(?=\Z|[[:upper:]])/g;

    if ( @parts ) {
        return join '-', map { lc }  @parts;
    }
    else {
        return lc $name;
    }
};

__PACKAGE__->meta->make_immutable;

1;

__END__

