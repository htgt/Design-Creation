package Test::DesignCreate::Role::OligoRegionCoordinates;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use Bio::SeqIO;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::Role::OligoRegionCoordinates

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::OligoRegionCoordinates' );
}

sub get_oligo_region_offset : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $offset = $o->get_oligo_region_offset('G5'), 'can get_oligo_region_offset';
    is $offset, $o->region_offset_G5, 'is expected offset value';
    throws_ok { $o->get_oligo_region_offset('M3') }
        qr/Attribute region_offset_M3 does not exist/, 'throws error on unexpected oligo name';

}

sub get_oligo_region_length : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $length = $o->get_oligo_region_length('G5'), 'can get_oligo_region_length';
    is $length, $o->region_length_G5, 'have correct oligo region length value';

    throws_ok {
        $o->get_oligo_region_length('M3')
    } qr/Attribute region_length_M3 does not exist/
        , 'throws error on unexpected oligo name';

}

sub target_data : Tests(6) {
    my $test = shift;
    ok my $o = $test->_get_gibson_test_object, 'can grab test object';

    ok $o->target_data, 'we have target_data';
    ok $o->have_target_data( 'target_start' ), 'we have a target_start value';
    is $o->get_target_data( 'target_start' ), 118964564, 'target_start is correct';
    is $o->get_target_data( 'chr_name' ), 11, 'chromosome is correct';
    ok !$o->have_target_data('foo'), 'does not have target data foo';
}

sub check_oligo_region_sizes : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_gibson_test_object, 'can grab test object';

    lives_ok{
        $o->check_oligo_region_sizes
    } 'checks pass for valid input';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj2 = $metaclass->new_object(
        dir              => $o->dir,
        region_length_5F => 10,
    );

    throws_ok{
        $new_obj2->check_oligo_region_sizes
    } qr/5F region too small/
        , 'throws error if a oligo region is too small';
}

sub _get_test_object {
    my ( $test, $species ) = @_;
    $species //= 'Mouse';

    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::Role::GapOligoCoordinates' ] );
    return $metaclass->new_object(
        dir => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
    );
}

sub _get_gibson_test_object {
    my ( $test, $params ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/oligo_pair_regions_gibson');

    # need oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::CmdRole::OligoPairRegionsGibson' ] );
    return $metaclass->new_object( dir => $dir );
}

1;

__END__
