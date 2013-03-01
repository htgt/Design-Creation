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

sub chr_name : Test(3) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    throws_ok{
        $test->test_class->new( dir => $dir, chr_strand => 1, chr_name => 30 )
    } qr/Invalid chromosome name, 30/, 'throws error with invalid chromosome name';

    throws_ok{
        $test->test_class->new( dir => $dir, chr_strand => 1, chr_name => 'Z' )
    } qr/Invalid chromosome name, Z/, 'throws error with invalid chromosome name';

    lives_ok{
        $test->test_class->new( dir => $dir, chr_strand => -1, chr_name => 'y' )
    } 'valid chromosome okay';
}

sub chr_strand : Test(3) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    throws_ok{
        $test->test_class->new( dir => $dir, chr_strand => 2, chr_name => '3' )
    } qr/Invalid strand 2/, 'throws error with invalid chromosome name';

    throws_ok{
        $test->test_class->new( dir => $dir, chr_strand => -2, chr_name => 'X' )
    } qr/Invalid strand -2/, 'throws error with invalid chromosome name';

    lives_ok{
        $test->test_class->new( dir => $dir, chr_strand => -1, chr_name => 'X' )
    } 'valid strand okay';
}

sub species : Test(2) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    throws_ok{
        $test->test_class->new( dir => $dir, chr_strand => 1, chr_name => '3', species => 'Human' )
    } qr/Invalid species Human/, 'throws error with invalid chromosome name';

    lives_ok{
        $test->test_class->new( dir => $dir, chr_strand => -1, chr_name => 'X', species => 'Mouse' )
    } 'mouse species  okay';
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
    my  $test = shift;

    return $test->test_class->new(
        dir        => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        chr_name   => 11,
        chr_strand => 1,
    );
}

1;

__END__
