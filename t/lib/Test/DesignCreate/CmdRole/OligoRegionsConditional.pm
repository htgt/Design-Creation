package Test::DesignCreate::CmdRole::OligoRegionsConditional;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::OligoRegionsConditional;
use DesignCreate::Cmd;

# Testing
# DesignCreate::CmdRole::OligoRegionsConditional
# DesignCreate::Action::OligoRegionsConditional ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::OligoRegionsConditional' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'oligo-regions-conditional',
        '--dir'           ,$dir->dirname,
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

    throws_ok {
        $test->test_class->new(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101177528, U_block_end => 101177428,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block start, 101177528, is greater than its end/
        , 'throws error when block start coordinate greater than its end coordinate';

    throws_ok {
        $test->test_class->new(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101177328, U_block_end => 101177428,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block has only 101 bases/
        , 'throws error when U or D block is too small';

    throws_ok {
        $test->test_class->new(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101178328, U_block_end => 101178528,
            D_block_start => 101176328, D_block_end => 101176528,
            chr_name      => 11,        chr_strand  => 1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/U block end: 101178528 can not be greater than D block start/
        , 'throws error when U block end is greater than D block start, +ve strand';

    throws_ok {
        $test->test_class->new(
            dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
            U_block_start => 101176328, U_block_end => 101176528,
            D_block_start => 101178328, D_block_end => 101178528,
            chr_name      => 11,        chr_strand  => -1,
            design_method => 'conditional',
        )->check_oligo_block_coordinates;
    } qr/D block end: 101178528 can not be greater than U block start/
        , 'throws error when D block end is greater than U block start, -ve strand';
}

sub get_oligo_region_coordinates : Tests(14) {
    my $test = shift;
    #
    # -ve stranded design
    #
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->get_oligo_region_coordinates( 'U5' )
        , 'can call get_oligo_region_coordinates';

    my $u5_real_end = ( $o->U_block_start + 100 );
    is $u5_start, $o->U_block_start, 'U5 start correct value';
    is $u5_end, $u5_real_end, 'U5 end correct value';

    ok my( $g5_start, $g5_end ) = $o->get_oligo_region_coordinates( 'G5' )
        , 'can call get_oligo_region_coordinates';
    my $g5_real_start = ( $o->U_block_start - ( $o->G5_region_offset + $o->G5_region_length ) );
    my $g5_real_end = ( $o->U_block_start - ( $o->G3_region_offset + 1 ) );
    is $g5_start, $g5_real_start, 'correct start value';
    is $g5_end, $g5_real_end, 'correct end value';

    #
    # -ve stranded design
    #
    ok $o = $test->_get_test_object( -1 ), 'can grab test object';

    ok my( $d3_start, $d3_end ) = $o->get_oligo_region_coordinates( 'D3' )
        , 'can call get_oligo_region_coordinates';

    is $d3_start, $o->D_block_start, 'correct D3 start value';
    is $d3_end, $o->D_block_start + 50, 'correct D3 end value';

    ok my( $g3_start, $g3_end ) = $o->get_oligo_region_coordinates( 'G3' )
        , 'can call get_oligo_region_coordinates';

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
    ok $o = $test->_get_test_object( -1 ), 'can grab test object';

    ok my( $g5_start_minus, $g5_end_minus ) = $o->get_oligo_region_coordinates( 'G5' )
        , 'can call get_oligo_region_gap_oligo for G5';

    is $g5_start_minus, $o->U_block_end + ( $o->G5_region_offset + 1 ), 'correct G5 start value';
    is $g5_end_minus, $o->U_block_end + ( $o->G5_region_offset + $o->G5_region_length ), 'correct G5 end value';

    ok my( $g3_start_minus, $g3_end_minus ) = $o->get_oligo_region_coordinates( 'G3' )
        , 'can call get_oligo_region_gap_oligo for G3';

    is $g3_start_minus, $o->D_block_start - ( $o->G3_region_offset + $o->G3_region_length )
        , 'correct G3 start value';
    is $g3_end_minus, $o->D_block_start - ( $o->G3_region_offset + 1 ), 'correct G3 end value';

    $o = $test->test_class->new(
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

sub get_oligo_region_u_or_d_oligo : Test(15) {
    my $test = shift;
    #
    # +ve stranded design
    #
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->get_oligo_region_coordinates( 'U5' )
        , 'can call get_oligo_region_coordinates';

    my $u5_real_end = ( $o->U_block_start + 100 );
    is $u5_start, $o->U_block_start, 'U5 start correct value';
    is $u5_end, $u5_real_end, 'U5 end correct value';

    ok my( $u3_start, $u3_end ) = $o->get_oligo_region_coordinates( 'U3' )
        , 'can call get_oligo_region_coordinates';

    my $u3_real_start = ( $o->U_block_start + 101 );
    is $u3_start, $u3_real_start, 'U3 start correct value';
    is $u3_end, $o->U_block_end, 'U3 end correct value';

    #
    # -ve stranded design
    #
    ok $o = $test->_get_test_object( -1 ), 'can grab test object';

    ok my( $d3_start_minus, $d3_end_minus ) = $o->get_oligo_region_coordinates( 'D3' )
        , 'can call get_oligo_region_coordinates';

    is $d3_start_minus, $o->D_block_start, 'correct D3 start value';
    is $d3_end_minus, $o->D_block_start + 50, 'correct D3 end value';

    ok my( $d5_start_minus, $d5_end_minus ) = $o->get_oligo_region_coordinates( 'D5' )
        , 'can call get_oligo_region_coordinates';

    is $d5_start_minus, $o->D_block_start + 51, 'correct D5 start value';
    is $d5_end_minus, $o->D_block_end, 'correct D5 end value';

    $o = $test->test_class->new(
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
}

sub build_oligo_target_regions : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->build_oligo_target_regions
    } 'can build_oligo_target_regions';

    for my $oligo ( qw( G5 U5 U3 D5 D3 G3 ) ) {
        my $oligo_file = $o->oligo_target_regions_dir->file( $oligo . '.fasta' );
        ok $o->oligo_target_regions_dir->contains( $oligo_file ), "$oligo oligo file exists";
    }
}

sub get_oligo_block_left_half_coords : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $start1, $end1 ) = $o->get_oligo_block_left_half_coords( 1, 10 );
    is $start1, 1, 'start correct';
    is $end1, 5, 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_left_half_coords( 1, 11 );
    is $start2, 1, 'start correct';
    is $end2, 6, 'end correct';
}

sub get_oligo_block_right_half_coords : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $start1, $end1 ) = $o->get_oligo_block_right_half_coords( 1, 10 );
    is $start1, 6, 'start correct';
    is $end1, 10, 'end correct';

    ok my( $start2, $end2 ) = $o->get_oligo_block_right_half_coords( 1, 11 );
    is $start2, 7, 'start correct';
    is $end2, 11, 'end correct';
}

sub get_oligo_block_coordinate : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u_block_start = $o->get_oligo_block_coordinate( 'U5', 'start' );
    is $u_block_start, 101176328, 'correct u block start';

    ok my $u_block_end = $o->get_oligo_block_coordinate( 'U5', 'end' );
    is $u_block_end, 101176528, 'correct u block end';

    throws_ok{
        $o->get_oligo_block_coordinate( 'G5', 'end' );
    } qr/Block oligo type must be U or D, not G5/
        , 'throws error if calling with non U or D oligo type';

    throws_ok{
        $o->get_oligo_block_coordinate( 'U5' );
    } qr/Must specify start or end block coordinate/
        , 'throws error if calling without start or end value';

    throws_ok{
        $o->get_oligo_block_coordinate( 'U5', 'blah' );
    } qr/Must specify start or end block coordinate/
        , 'throws error if calling without start or end value';
}

sub _get_test_object {
    my ( $test, $strand ) = @_;
    $strand //= 1;

    return $test->test_class->new(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        U_block_start => $strand == 1 ? 101176328 : 101177328,
        U_block_end   => $strand == 1 ? 101176528 : 101177428,
        D_block_start => $strand == 1 ? 101177328 : 101176328,
        D_block_end   => $strand == 1 ? 101177528 : 101176428,
        chr_name      => 11,
        chr_strand    => $strand,
        design_method => 'conditional',
    );
}

1;

__END__
