package Test::DesignCreate::Role::EnsEMBL;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Role::EnsEMBL

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::EnsEMBL' );
}

sub get_sequence : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my $seq = $o->_get_sequence( 1, 10, 11 );
    isa_ok $seq, 'Bio::EnsEMBL::Slice';
    is $seq->seq, 'NNNNNNNNNN', 'sequence is correct';

    throws_ok{
        $o->_get_sequence( 10, 1, 11 );
    } qr/Start must be less than end/
        , 'throws error if start after end';
}

sub ensembl_util : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $ensembl_util = $o->ensembl_util, 'can grab ensembl util';
    isa_ok $ensembl_util, 'LIMS2::Util::EnsEMBL';

    ok my $slice_adaptor = $o->ensembl_util->slice_adaptor, 'can grab slice adaptor';
    isa_ok $slice_adaptor, 'Bio::EnsEMBL::DBSQL::SliceAdaptor';
}

sub _get_test_object {
    my ( $test ) = @_;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        design_method => 'deletion',
    );
}

1;

__END__