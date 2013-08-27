package DesignCreate::Cmd;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::VERSION = '0.010';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( MooseX::App::Cmd );

sub plugin_search_path {
    return [ 'DesignCreate::Action' ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__
