package DesignCreate::Cmd;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::VERSION = '0.037';
}
## use critic


=head1 NAME

DesignCreate::Cmd

=head1 DESCRIPTION

Base class for all App Commands

=cut

use Moose;
use Log::Log4perl qw( :levels );
use namespace::autoclean;

extends qw( MooseX::App::Cmd::Command );
with qw(
MooseX::Log::Log4perl
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

has is_step => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => [ 'NoGetopt' ],
    default => 0,
);

sub BUILD {
    my $self = shift;

    # Add command name as a design parameter
    my $cmd_name = $self->command_names;
    $self->set_param( 'command-name', $cmd_name );

    my $log_level
        = $self->trace   ? 'TRACE'
        : $self->debug   ? 'DEBUG'
        : $self->verbose ? 'INFO'
        :                  'WARN';

    my $dir_name = $self->dir->stringify;
    my $log_file_name = 'design-create.log';
    if ( $self->is_step ) {
        $log_file_name = $cmd_name . '.log';
    }
    else {
        # if 'complete' cmd wipe the work directory first
        $self->dir->rmtree();
    }
    # create the work directory if it does not exist
    $self->dir->mkpath();

    # Log output goes to STDERR and a log file ( the log file level is alway DEBUG )
    # the STDERR log level is user specified, defaults to WARN
## no critic(ValuesAndExpressions::ProhibitImplicitNewlines)
    my $conf = "
    log4perl.logger = DEBUG, FileApp, ScreenApp

    log4perl.appender.FileApp                          = Log::Log4perl::Appender::File
    log4perl.appender.FileApp.filename                 = $dir_name/$log_file_name
    log4perl.appender.FileApp.mode                     = write
    log4perl.appender.FileApp.layout                   = PatternLayout
    log4perl.appender.FileApp.layout.ConversionPattern = %d %c %p %x %m%n

    log4perl.appender.ScreenApp                          = Log::Log4perl::Appender::Screen
    log4perl.appender.ScreenApp.stderr                   = 1
    log4perl.appender.ScreenApp.layout                   = PatternLayout
    log4perl.appender.ScreenApp.layout.ConversionPattern = %d %p %x %m%n
    log4perl.appender.ScreenApp.Threshold                = $log_level
    ";
## use critic
    Log::Log4perl->init(\$conf);

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
