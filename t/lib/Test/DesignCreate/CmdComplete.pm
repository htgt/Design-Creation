package Test::DesignCreate::CmdComplete;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use base qw( Test::Class Class::Data::Inheritable );

use DesignCreate::CmdComplete;

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::CmdComplete' );
}

1;

__END__
