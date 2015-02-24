package Test::DesignCreate::Role::EnsEMBL;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::Role::EnsEMBL

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::EnsEMBL' );
}

sub get_sequence : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my $seq = $o->get_slice( 1, 10, 11 );
    isa_ok $seq, 'Bio::EnsEMBL::Slice';
    is $seq->seq, 'NNNNNNNNNN', 'sequence is correct';

    throws_ok{
        $o->get_slice( 10, 1, 11 );
    } qr/Start must be less than end/
        , 'throws error if start after end';
}

#TODO add test for repeat masked sequence sp12 Wed 24 Jul 2013 12:55:17 BST

sub ensembl_util : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $ensembl_util = $o->ensembl_util, 'can grab ensembl util';
    isa_ok $ensembl_util, 'WebAppCommon::Util::EnsEMBL';

    ok my $slice_adaptor = $o->ensembl_util->slice_adaptor, 'can grab slice adaptor';
    isa_ok $slice_adaptor, 'Bio::EnsEMBL::DBSQL::SliceAdaptor';

    ok my $exon_adaptor = $o->ensembl_util->exon_adaptor, 'can grab exon adaptor';
    isa_ok $exon_adaptor, 'Bio::EnsEMBL::DBSQL::ExonAdaptor';
}

sub _get_test_object {
    my ( $test ) = @_;

    my $metaclass = $test->get_test_object_metaclass();
    my $o = $metaclass->new_object(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        design_method => 'deletion',
    );
    $o->set_param( 'species', 'Mouse' );

    return $o;
}

1;

__END__
