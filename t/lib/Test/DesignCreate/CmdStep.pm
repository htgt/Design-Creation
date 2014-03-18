package Test::DesignCreate::CmdStep;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Test::MockObject;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate;
use DesignCreate::CmdStep;

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::CmdStep' );
}

=head2 get_test_object_metaclass

Use meta object to dynamically create moose classes that consume the specific
roles we wish to test. Each CmdRole test class has a test_role class
data value set that specifies which role we are testing.

=cut
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

=head2 get_mock_lims2_api

Setup a mock LIMS2 api so we can test the PUT and POST requests that are
sent to the api are as expected.

=cut
sub get_mock_lims2_api {
    my $test = shift;

    my $mock_lims2_api = Test::MockObject->new;
    $mock_lims2_api->set_isa( 'LIMS2::REST::Client' );
    $mock_lims2_api->mock( 'POST', sub{ { id => 123 } } );
    $mock_lims2_api->mock( 'PUT', sub{ } );

    return $mock_lims2_api;
}

1;

__END__
