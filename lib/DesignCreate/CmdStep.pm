package DesignCreate::CmdStep;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdStep::VERSION = '0.028';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( MooseX::App::Cmd );

sub plugin_search_path {
    return [ 'DesignCreate::Cmd::Step' ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__
