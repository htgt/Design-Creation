package Test::DesignCreate::CmdRole::OligoRegionsConditional;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoRegionsConditional
# DesignCreate::Action::OligoRegionsConditional ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoRegionsConditional' );
}

sub valid_run_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'oligo-regions-conditional',
        '--dir'                     ,$o->dir->stringify,
        '--region-length-u-block'   ,200,
        '--region-offset-u-block'   ,200,
        '--region-length-d-block'   ,200,
        '--region-offset-d-block'   ,100,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub check_oligo_blocks : Test(3) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->check_oligo_blocks
    } 'can call check_oligo_blocks';

    throws_ok {
        $metaclass->new_object(
            dir                    => $o->dir,
            region_length_U_block  => 101,
            region_offset_U_block  => 200,
            region_length_D_block  => 200,
            region_offset_D_block  => 100,
        )->check_oligo_blocks;
    } qr/U block has only 101 bases/
        , 'throws error when U or D block is too small';
}

sub calculate_oligo_region_coordinates : Tests(43) {
    my $test = shift;

    #my $metaclass = $test->get_test_object_metaclass();
    ok my $plus_strand_obj = $test->_get_test_object, 'can grab plus strand test object';
    _check_coordinates(
        $plus_strand_obj,
        {
            'region_start_G5' => 110000 - ( 200 + 200 + 4000 + 1000 ),
            'region_end_G5'   => 110000 - ( 200 + 200 + 4000 ),
            'region_start_G3' => 111000 + 100 + 200 + 4000,
            'region_end_G3'   => 111000 + 100 + 200 + 4000 + 1000,
            'region_start_U5' => 110000 - ( 200 + 200 ),
            'region_end_U5'   => 110000 - ( 200 + 101 ),
            'region_start_U3' => 110000 - ( 200 + 100 ),
            'region_end_U3'   => 110000 - 200,
            'region_start_D5' => 111000 + 100,
            'region_end_D5'   => 111000 + 100 + 99,
            'region_start_D3' => 111000 + 100 + 100,
            'region_end_D3'   => 111000 + 100 + 200,
        },
        'plus_strand'
    );


    ok my $overlap_test_obj = $test->_get_test_object( { u_overlap => 20, d_overlap => 10 } ),
        'can grab test object';
    _check_coordinates(
        $overlap_test_obj,
        {
            'region_start_G5' => 110000 - ( 200 + 200 + 4000 + 1000 ),
            'region_end_G5'   => 110000 - ( 200 + 200 + 4000 ),
            'region_start_G3' => 111000 + 100 + 200 + 4000,
            'region_end_G3'   => 111000 + 100 + 200 + 4000 + 1000,
            'region_start_U5' => 110000 - ( 200 + 200 ),
            'region_end_U5'   => 110000 - ( 200 + 101 ) + 20,
            'region_start_U3' => 110000 - ( 200 + 100 ) - 20,
            'region_end_U3'   => 110000 - 200,
            'region_start_D5' => 111000 + 100,
            'region_end_D5'   => 111000 + 100 + 99 + 10,
            'region_start_D3' => 111000 + 100 + 100 - 10,
            'region_end_D3'   => 111000 + 100 + 200,
        },
        'plus_strand_overlap'
    );

    ok my $minus_strand_obj = $test->_get_test_object(), 'can grab minus strand test object';
    ok $minus_strand_obj->target_data->{chr_strand} = -1, 'can overwrite strand to -1';
    _check_coordinates(
        $minus_strand_obj,
        {
            'region_start_G5' => 111000 + 200 + 200 + 4000,
            'region_end_G5'   => 111000 + 200 + 200 + 4000 + 1000,
            'region_start_G3' => 110000 - ( 100 + 200 + 4000 + 1000 ),
            'region_end_G3'   => 110000 - ( 100 + 200 + 4000 ),
            'region_start_U5' => 111000 + 200 + 100,
            'region_end_U5'   => 111000 + 200 + 200,
            'region_start_U3' => 111000 + 200,
            'region_end_U3'   => 111000 + 200 + 99,
            'region_start_D5' => 110000 - ( 100 + 100 ),
            'region_end_D5'   => 110000 - 100,
            'region_start_D3' => 110000 - ( 100 + 200 ),
            'region_end_D3'   => 110000 - ( 100 + 101 ),
        },
        'minus_strand'
    );
}

sub _check_coordinates {
    my ( $obj, $expected, $test_type ) = @_;

    lives_ok {
        $obj->calculate_oligo_region_coordinates
    } "can call calculate_oligo_region_coordinates for $test_type test";

    for my $coord_type ( keys %{ $expected } ) {
        is $obj->$coord_type, $expected->{$coord_type}, "$coord_type is correct for $test_type test";
   }

   return;
}

sub get_oligo_region_coordinates : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->get_oligo_region_coordinates
    } 'can build_oligo_target_regions';


    my $oligo_region_file = $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $oligo_region_file )
        , "$oligo_region_file oligo file exists";
}

sub get_oligo_block_left_half_coords : Test(14) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $start1, $end1 ) = $o->get_oligo_block_left_half_coords( 'U', 100 );
    is $start1, 100, 'start correct';
    is $end1, 199, 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_left_half_coords( 'D', 100 );
    is $start2, 100, 'start correct';
    is $end2, 199, 'end correct';

    ok $o = $test->_get_test_object( { u_overlap => 10, d_overlap => 15 } ), 'can grab another test object';

    ok my( $start3, $end3 ) = $o->get_oligo_block_left_half_coords( 'U', 100 );
    is $start3, 100, 'start correct';
    is $end3, 209, 'end correct';

    ok my( $start4, $end4 ) = $o->get_oligo_block_left_half_coords( 'D', 100 );
    is $start4, 100, 'start correct';
    is $end4, 214, 'end correct';
}

sub get_oligo_block_right_half_coords : Test(14) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $start1, $end1 ) = $o->get_oligo_block_right_half_coords( 'U', 100, 300 );
    is $start1, 200 , 'start correct';
    is $end1, 300 , 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_right_half_coords( 'D', 100, 300 );
    is $start2, 200, 'start correct';
    is $end2, 300, 'end correct';

    ok $o = $test->_get_test_object( { u_overlap => 10, d_overlap => 15 } ), 'can grab another test object';

    ok my( $start3, $end3 ) = $o->get_oligo_block_right_half_coords( 'U', 100, 300 );
    is $start3, 190 , 'start correct';
    is $end3, 300 , 'end correct';

    ok my( $start4, $end4 ) = $o->get_oligo_block_right_half_coords( 'D', 100, 300 );
    is $start4, 185, 'start correct';
    is $end4, 300, 'end correct';
}

sub get_oligo_block_attribute : Test(12) {
    my $test = shift;
    ok my $o = $test->_get_test_object( { u_overlap => 1 } ), 'can grab test object';

    ok my $u_block_offset = $o->get_oligo_block_attribute( 'U', 'offset' );
    is $u_block_offset, 200, 'correct u block offset';

    ok my $d_block_offset = $o->get_oligo_block_attribute( 'D', 'offset' );
    is $d_block_offset, 100, 'correct d block offset';

    ok my $u_block_length = $o->get_oligo_block_attribute( 'U', 'length' );
    is $u_block_length, 200, 'correct u block length';

    ok my $u_block_overlap = $o->get_oligo_block_attribute( 'U', 'overlap' );
    is $u_block_overlap, 1, 'correct u block overlap';

    throws_ok{
        $o->get_oligo_block_attribute( 'G', 'end' );
    } 'DesignCreate::Exception::NonExistantAttribute'
        , 'throws error if calling with non U or D oligo type';

    throws_ok{
        $o->get_oligo_block_attribute( 'U' );
    } 'DesignCreate::Exception::NonExistantAttribute'
        , 'throws error if calling without start or end value';

    throws_ok{
        $o->get_oligo_block_attribute( 'U', 'blah' );
    } 'DesignCreate::Exception::NonExistantAttribute'
        , 'throws error if calling without start or end value';
}

sub _get_test_object {
    my ( $test, $params ) = @_;
    my $u_overlap = $params->{u_overlap} || 0;
    my $d_overlap = $params->{d_overlap} || 0;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/oligo_regions_conditional');

    # need oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir                    => $dir,
        region_length_U_block  => 200,
        region_offset_U_block  => 200,
        region_overlap_U_block => $u_overlap,
        region_length_D_block  => 200,
        region_offset_D_block  => 100,
        region_overlap_D_block => $d_overlap,
    );
}

1;

__END__
