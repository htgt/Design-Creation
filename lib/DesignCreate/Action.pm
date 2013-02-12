package DesignCreate::Action;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsDir/;
use DesignCreate::Types qw( ArrayRefOfOligos DesignMethod );
use Log::Log4perl qw( :levels );
use Try::Tiny;
use Const::Fast;
use namespace::autoclean;

extends qw( MooseX::App::Cmd::Command );
with qw( MooseX::Log::Log4perl );

const my $CURRENT_ASSEMBLY => 'GRCm38';
const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';
const my $DEFAULT_AOS_OUTPUT_DIR_NAME => 'aos_output';

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

has log_layout => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Specify the Log::Log4perl layout',
    default       => '%d %c %p %m%n',
    cmd_flag      => 'log-layout'
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

#TODO move attributes below to somewhere more logical
has assembly => (
    is      => 'ro',
    isa     => 'Str',
    traits  => [ 'NoGetopt' ],
    default => sub { $CURRENT_ASSEMBLY },
);

has design_method => (
    is            => 'ro',
    isa           => DesignMethod,
    traits        => [ 'Getopt' ],
    required      => 1,
    default       => 'deletion',
    documentation => 'Design type, Deletion, Insertion, Conditional',
    cmd_flag      => 'design-method',
);

has expected_oligos => (
    is         => 'ro',
    isa        => ArrayRefOfOligos,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

has ensembl_util => (
    is         => 'ro',
    isa        => 'LIMS2::Util::EnsEMBL',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
    handles    => [ qw( slice_adaptor ) ],
);

sub _build_ensembl_util {
    my $self = shift;
    require LIMS2::Util::EnsEMBL;

    return LIMS2::Util::EnsEMBL->new( species => $self->species );
}

#TODO account for all design type
sub _build_expected_oligos {
    my $self = shift;

    if ( $self->design_method eq 'deletion' ) {
        return [ qw( G5 U5 D3 G3 ) ];
    }
    else {
        die( 'Unknown design method ' . $self->design_method );
    }
}

has validated_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the validated oligos, '
                     . " defaults to [design_dir]/$DEFAULT_VALIDATED_OLIGO_DIR_NAME",
    coerce        => 1,
    cmd_flag      => 'validated-oligo-dir',
    lazy_build    => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME )->absolute;
    $validated_oligo_dir->rmtree();
    $validated_oligo_dir->mkpath();

    return $validated_oligo_dir;
}

has aos_output_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the oligo yaml files'
                     . " defaults to [design_dir]/$DEFAULT_AOS_OUTPUT_DIR_NAME",
    coerce        => 1,
    lazy_build    => 1,
    cmd_flag      => 'aos-oligo-dir',
);

sub _build_aos_output_dir {
    my $self = shift;

    my $aos_output_dir = $self->dir->subdir( $DEFAULT_AOS_OUTPUT_DIR_NAME )->absolute;
    $aos_output_dir->rmtree();
    $aos_output_dir->mkpath();

    return $aos_output_dir;
}

sub BUILD {
    my $self = shift;

    my $log_level
        = $self->trace   ? $TRACE
        : $self->debug   ? $DEBUG
        : $self->verbose ? $INFO
        :                  $WARN;

    Log::Log4perl->easy_init( { level => $log_level, layout => $self->log_layout } );
    return;
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

