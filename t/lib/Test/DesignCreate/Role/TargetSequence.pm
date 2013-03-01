package Test::DesignCreate::Role::TargetSequence;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::TargetSequence;

# Testing
# DesignCreate::Role::TargetSequence

BEGIN {
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::TargetSequence' );
}

sub get_sequence : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my $seq = $o->get_sequence( 1,10 );
    is $seq, 'NNNNNNNNNN', 'sequence is correct';

    throws_ok{
        $o->get_sequence( 10, 1 );
    } qr/Start must be less than end/
        , 'throws error if start after end';
}

sub _get_test_object {
    my ( $test, $strand ) = @_;
    $strand //= 1;

    return $test->test_class->new(
        dir         => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        chr_name    => 11,
        chr_strand  => $strand,
    );
}

1;

__END__
