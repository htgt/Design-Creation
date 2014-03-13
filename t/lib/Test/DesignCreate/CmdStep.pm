package Test::DesignCreate::CmdStep;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate;
use DesignCreate::CmdStep;

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::CmdStep' );
}

sub get_test_object_metaclass {
    my ( $test, $extra_roles ) = @_;

    $extra_roles ||= [];

    my $metaclass = Moose::Meta::Class->create(
        'Test::ObjectRole::DesignCreate::Test' => (
            superclasses => [ 'Test::ObjectRole::DesignCreate' ],
            roles        => [ $test->test_role, @{ $extra_roles } ],
        )
    );

    return $metaclass
}

1;

__END__
