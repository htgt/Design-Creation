package DesignCreate::Action;

=head1 NAME

DesignCreate::Action

=head1 DESCRIPTION

Base class for all App Commands
Common attributes and methods for these commands are stored in the
DesignCreate::Role::Action role. ( see this module for explanation )

=cut

use Moose;
use Log::Log4perl qw( :levels );
use namespace::autoclean;

extends qw( MooseX::App::Cmd::Command );
with qw(
MooseX::Log::Log4perl
DesignCreate::Role::Action
DesignCreate::Role::EnsEMBL
);

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

sub BUILD {
    my $self = shift;

    # Add command name as a design parameter
    $self->set_param( 'command-name', $self->command_names );

    my $log_level
        = $self->trace   ? $TRACE
        : $self->debug   ? $DEBUG
        : $self->verbose ? $INFO
        :                  $WARN;

    # Log output goes to STDERR and a log file
    Log::Log4perl->easy_init(
        {
            level    => $log_level,
            file     => ">" . $self->dir . '/design-create.log',
            layout   => '%d %c %p %x %m%n',
        },
        {
            level    => $log_level,
            file     => "STDERR",
            layout   => '%d %c %p %x %m%n',
        },
    );

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
