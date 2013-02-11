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

