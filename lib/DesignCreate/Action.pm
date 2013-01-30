package DesignCreate::Action;

use strict;
use warnings FATAL => 'all';

use Moose;
use Log::Log4perl qw( :levels );
use MooseX::Types::Path::Class;
use Try::Tiny;
use namespace::autoclean;

extends qw( MooseX::App::Cmd::Command );
with qw( MooseX::Log::Log4perl );

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
    isa           => 'Path::Class::Dir',
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

