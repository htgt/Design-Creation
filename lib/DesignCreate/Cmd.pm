package DesignCreate::Cmd;

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( MooseX::App::Cmd );

sub plugin_search_path {
    return [ 'DesignCreate::Action' ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__
