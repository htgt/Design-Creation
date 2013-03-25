package Test::DesignCreate::CmdRole::OligoRegionsConditional;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoRegionsConditional
# DesignCreate::Action::OligoRegionsConditional ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoRegionsConditional' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'oligo-regions-conditional',
        '--dir'           ,$dir->stringify,
        '--u-block-start' ,101176328,
        '--u-block-end'   ,101176528,
        '--d-block-start' ,101177328,
        '--d-block-end'   ,101177528,
        '--chromosome'    ,11,
        '--strand'        ,1,
        '--design-method' ,'conditional',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub check_oligo_block_coordinates : Test(4) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();

    throws_ok {
        $metaclass->new_object(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101177528, U_block_end => 101177428,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block start, 101177528, is greater than its end/
        , 'throws error when block start coordinate greater than its end coordinate';

    throws_ok {
        $metaclass->new_object(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101177328, U_block_end => 101177428,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block has only 101 bases/
        , 'throws error when U or D block is too small';

    throws_ok {
        $metaclass->new_object(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101178328, U_block_end => 101178528,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block end: 101178528 can not be greater than D block start/
        , 'throws error when U block end is greater than D block start, +ve strand';

    throws_ok {
        $metaclass->new_object(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101176328, U_block_end => 101176528,
            D_block_start => 101178328, D_block_end => 101178528,
            chr_name      => 11,        chr_strand  => -1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/D block end: 101178528 can not be greater than U block start/
        , 'throws error when D block end is greater than U block start, -ve strand';
}

sub coordinates_for_oligo : Tests(14) {
    my $test = shift;
    #
    # -ve stranded design
    #
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->coordinates_for_oligo( 'U5' )
        , 'can call coordinates_for_oligo';

    my $u5_real_end = ( $o->U_block_start + 100 );
    is $u5_start, $o->U_block_start, 'U5 start correct value';
    is $u5_end, $u5_real_end, 'U5 end correct value';

    ok my( $g5_start, $g5_end ) = $o->coordinates_for_oligo( 'G5' )
        , 'can call coordinates_for_oligo';
    my $g5_real_start = ( $o->U_block_start - ( $o->G5_region_offset + $o->G5_region_length ) );
    my $g5_real_end = ( $o->U_block_start - ( $o->G3_region_offset + 1 ) );
    is $g5_start, $g5_real_start, 'correct start value';
    is $g5_end, $g5_real_end, 'correct end value';

    #
    # -ve stranded design
    #
    ok $o = $test->_get_test_object( { strand => -1 } ), 'can grab test object';

    ok my( $d3_start, $d3_end ) = $o->coordinates_for_oligo( 'D3' )
        , 'can call coordinates_for_oligo';

    is $d3_start, $o->D_block_start, 'correct D3 start value';
    is $d3_end, $o->D_block_start + 50, 'correct D3 end value';

    ok my( $g3_start, $g3_end ) = $o->coordinates_for_oligo( 'G3' )
        , 'can call coordinates_for_oligo';

    is $g3_start, $o->D_block_start - ( $o->G3_region_offset + $o->G3_region_length )
        , 'correct G3 start value';
    is $g3_end, $o->D_block_start - ( $o->G3_region_offset + 1 ), 'correct G3 end value';
}

sub get_oligo_region_gap_oligo : Test(15) {
    my $test = shift;
    #
    # -ve stranded design
    #
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $g3_start, $g3_end ) = $o->get_oligo_region_gap_oligo( 'G3' )
        , 'can call get_oligo_region_gap_oligo for G3';
    my $g3_real_start = ( $o->D_block_end + ( $o->G3_region_offset + 1 ) );
    my $g3_real_end = ( $o->D_block_end + ( $o->G3_region_offset + $o->G3_region_length ) );
    is $g3_start, $g3_real_start, 'correct start value';
    is $g3_end, $g3_real_end, 'correct end value';

    ok my( $g5_start, $g5_end ) = $o->get_oligo_region_gap_oligo( 'G5' )
        , 'can call get_oligo_region_gap_oligo for G5';
    my $g5_real_start = ( $o->U_block_start - ( $o->G5_region_offset + $o->G5_region_length ) );
    my $g5_real_end = ( $o->U_block_start - ( $o->G3_region_offset + 1 ) );
    is $g5_start, $g5_real_start, 'correct start value';
    is $g5_end, $g5_real_end, 'correct end value';

    #
    # -ve stranded design
    #
    ok $o = $test->_get_test_object( { strand => -1 } ), 'can grab test object';

    ok my( $g5_start_minus, $g5_end_minus ) = $o->coordinates_for_oligo( 'G5' )
        , 'can call get_oligo_region_gap_oligo for G5';

    is $g5_start_minus, $o->U_block_end + ( $o->G5_region_offset + 1 ), 'correct G5 start value';
    is $g5_end_minus, $o->U_block_end + ( $o->G5_region_offset + $o->G5_region_length ), 'correct G5 end value';

    ok my( $g3_start_minus, $g3_end_minus ) = $o->coordinates_for_oligo( 'G3' )
        , 'can call get_oligo_region_gap_oligo for G3';

    is $g3_start_minus, $o->D_block_start - ( $o->G3_region_offset + $o->G3_region_length )
        , 'correct G3 start value';
    is $g3_end_minus, $o->D_block_start - ( $o->G3_region_offset + 1 ), 'correct G3 end value';

    my $metaclass = $test->get_test_object_metaclass();
    $o = $metaclass->new_object(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start => 101177328,     U_block_end      => 101177428,
        D_block_start => 101176328,     D_block_end      => 101176428,
        chr_name      => 11,            chr_strand       => 1,
        design_method => 'conditional', G5_region_length => 1,
    );

    throws_ok {
        $o->get_oligo_region_gap_oligo( 'G5' )
    } qr/Start \d+, greater than or equal to end \d+/
        , 'throws start greater than end error';
}

sub get_oligo_region_u_or_d_oligo : Test(16) {
    my $test = shift;
    #
    # +ve stranded design
    #
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->coordinates_for_oligo( 'U5' )
        , 'can call coordinates_for_oligo';

    my $u5_real_end = ( $o->U_block_start + 100 );
    is $u5_start, $o->U_block_start, 'U5 start correct value';
    is $u5_end, $u5_real_end, 'U5 end correct value';

    ok my( $u3_start, $u3_end ) = $o->coordinates_for_oligo( 'U3' )
        , 'can call coordinates_for_oligo';

    my $u3_real_start = ( $o->U_block_start + 101 );
    is $u3_start, $u3_real_start, 'U3 start correct value';
    is $u3_end, $o->U_block_end, 'U3 end correct value';

    #
    # -ve stranded design
    #
    ok $o = $test->_get_test_object( { strand => -1 } ), 'can grab test object';

    ok my( $d3_start_minus, $d3_end_minus ) = $o->coordinates_for_oligo( 'D3' )
        , 'can call coordinates_for_oligo';

    is $d3_start_minus, $o->D_block_start, 'correct D3 start value';
    is $d3_end_minus, $o->D_block_start + 50, 'correct D3 end value';

    ok my( $d5_start_minus, $d5_end_minus ) = $o->coordinates_for_oligo( 'D5' )
        , 'can call coordinates_for_oligo';

    is $d5_start_minus, $o->D_block_start + 51, 'correct D5 start value';
    is $d5_end_minus, $o->D_block_end, 'correct D5 end value';

    my $metaclass = $test->get_test_object_metaclass();
    $o = $metaclass->new_object(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start => 101177328,     U_block_end      => 101177329,
        D_block_start => 101176328,     D_block_end      => 101176428,
        chr_name      => 11,            chr_strand       => 1,
        design_method => 'conditional', G5_region_length => 1,
    );

    throws_ok {
        $o->get_oligo_region_u_or_d_oligo( 'U5' )
    } qr/Start \d+, greater than or equal to end \d+/
        , 'throws start greater than end error';

    throws_ok {
        $o->get_oligo_region_u_or_d_oligo( 'X5' )
    } qr/Block oligo type must be U or D, not X5/
        , 'throws error when unknown oligo type';
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

    ok my( $start1, $end1 ) = $o->get_oligo_block_left_half_coords( 'U' );
    is $start1, 101176328, 'start correct';
    is $end1, 101176428, 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_left_half_coords( 'D' );
    is $start2, 101177327, 'start correct';
    is $end2, 101177427, 'end correct';

    ok $o = $test->_get_test_object( { u_offset => 10, d_offset => 15 } ), 'can grab another test object';

    ok my( $start3, $end3 ) = $o->get_oligo_block_left_half_coords( 'U' );
    is $start3, 101176328, 'start correct';
    is $end3, 101176438, 'end correct';

    ok my( $start4, $end4 ) = $o->get_oligo_block_left_half_coords( 'D' );
    is $start4, 101177327, 'start correct';
    is $end4, 101177442, 'end correct';
}

sub get_oligo_block_right_half_coords : Test(14) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $start1, $end1 ) = $o->get_oligo_block_right_half_coords( 'U' );
    is $start1, 101176429 , 'start correct';
    is $end1, 101176528 , 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_right_half_coords( 'D' );
    is $start2, 101177428, 'start correct';
    is $end2, 101177528, 'end correct';

    ok $o = $test->_get_test_object( { u_offset => 10, d_offset => 15 } ), 'can grab another test object';

    ok my( $start3, $end3 ) = $o->get_oligo_block_right_half_coords( 'U' );
    is $start3, 101176419 , 'start correct';
    is $end3, 101176528 , 'end correct';

    ok my( $start4, $end4 ) = $o->get_oligo_block_right_half_coords( 'D' );
    is $start4, 101177413, 'start correct';
    is $end4, 101177528, 'end correct';
}

sub get_oligo_block_attribute : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u_block_start = $o->get_oligo_block_attribute( 'U', 'start' );
    is $u_block_start, 101176328, 'correct u block start';

    ok my $u_block_end = $o->get_oligo_block_attribute( 'U', 'end' );
    is $u_block_end, 101176528, 'correct u block end';

    ok my $u_block_length = $o->get_oligo_block_attribute( 'U', 'length' );
    is $u_block_length, 201, 'correct u block length';

    #ok my $u_block_offset = $o->get_oligo_block_attribute( 'U', 'offset' );
    #is $u_block_offset, 0, 'correct u block offset';

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

sub D_block_length : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $D_block_length = $o->D_block_length, 'can call D_block_length';
    is $D_block_length, 202, 'correct D_block_length value';
}

sub D_block_offset : Test(no_plan) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();
    ok my $o = $metaclass->new_object(
        dir => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start => 101176328, U_block_end => 101176528,
        D_block_start => 101177327, D_block_end => 101177528,
        chr_name      => 11       , chr_strand  => 1,
        design_method => 'conditional',
    );

    ok my $D_block_offset = $o->D_block_offset, 'can call D_block_offset';
    is $D_block_offset, 50, 'correct D_block_offset value';
}

sub U_block_length : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $U_block_length = $o->U_block_length, 'can call U_block_length';
    is $U_block_length, 201, 'correct U_block_length value';
}

sub U_block_offset : Test(no_plan) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();
    ok my $o = $metaclass->new_object(
        dir => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start => 101176328, U_block_end => 101176528,
        D_block_start => 101177327, D_block_end => 101177528,
        chr_name      => 11       , chr_strand  => 1,
        design_method => 'conditional',
    );

    ok my $U_block_offset = $o->U_block_offset, 'can call U_block_offset';
    is $U_block_offset, 50, 'correct U_block_offset value';
}

sub _get_test_object {
    my ( $test, $params ) = @_;
    my $strand = $params->{strand} || 1;
    my $u_offset = $params->{u_offset} || 0;
    my $d_offset = $params->{d_offset} || 0;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir            => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start  => $strand == 1 ? 101176328 : 101177328,
        U_block_end    => $strand == 1 ? 101176528 : 101177428,
        U_block_offset => $u_offset,
        D_block_start  => $strand == 1 ? 101177327 : 101176328,
        D_block_end    => $strand == 1 ? 101177528 : 101176428,
        D_block_offset => $d_offset,
        chr_name       => 11,
        chr_strand     => $strand,
        design_method  => 'conditional',
    );
}

1;

__END__
