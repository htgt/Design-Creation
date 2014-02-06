package Test::DesignCreate::Role::OligoRegionCoordinatesGibson;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Role::OligoRegionCoordinatesGibson

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::OligoRegionCoordinatesGibson' );
}

sub target_data : Tests(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok $o->target_data, 'we have target_data';
    ok $o->have_target_data( 'target_start' ), 'we have a target_start value';
    is $o->get_target_data( 'target_start' ), 118964564, 'target_start is correct';
    is $o->get_target_data( 'chr_name' ), 11, 'chromosome is correct';
    ok !$o->have_target_data('foo'), 'does not have target data foo';
}

sub check_oligo_region_sizes : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

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
