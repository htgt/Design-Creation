package Test::DesignCreate::CmdRole::OligoRegionsInsDel;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use Bio::SeqIO;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoRegionsInsDel
# DesignCreate::Cmd::Step::OligoRegionsInsDel ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoRegionsInsDel' );
}

sub valid_run_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'oligo-regions-ins-del',
        '--dir', $o->dir->stringify,
        '--strand', 1,
        '--design-method', 'deletion',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub coordinates_for_oligo : Tests(18) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->coordinates_for_oligo( 'U5' )
        , 'can call coordinates_for_oligo';

    my $target_start = $o->get_target_data( 'target_start' );
    my $target_end   = $o->get_target_data( 'target_end' );

    my $u5_real_start = ( $target_start - ( $o->region_offset_U5 + $o->region_length_U5 ) );
    my $u5_real_end = ( $target_start - ( $o->region_offset_U5 + 1 ) );
    is $u5_start, $u5_real_start, 'correct start value';
    is $u5_end, $u5_real_end, 'correct end value';

    ok my( $g3_start, $g3_end ) = $o->coordinates_for_oligo( 'G3' )
        , 'can call coordinates_for_oligo';
    my $g3_real_start = ( $target_end + ( $o->region_offset_G3 + 1 ) );
    my $g3_real_end = ( $target_end + ( $o->region_offset_G3 + $o->region_length_G3 ) );
    is $g3_start, $g3_real_start, 'correct start value';
    is $g3_end, $g3_real_end, 'correct end value';

    # -ve stranded design
    ok $o->target_data->{chr_strand} = -1, 'set strand -1';

    ok my( $d3_start, $d3_end ) = $o->coordinates_for_oligo( 'D3' )
        , 'can call coordinates_for_oligo';

    #because these -ve and +ve strand deletion designs are symmetric the coordinates:
    #   U5 region on the +ve design should be the same as D3 region on the -ve design
    #   G5 region on the +ve design should be the same as G3 region on the -ve design

    is $d3_start, $u5_real_start, 'correct start value';
    is $d3_end, $u5_real_end, 'correct end value';

    ok my( $g5_start, $g5_end ) = $o->coordinates_for_oligo( 'G5' )
        , 'can call coordinates_for_oligo';

    is $g5_start, $g3_real_start, 'correct start value';
    is $g5_end, $g3_real_end, 'correct end value';

    ok my $new_obj = $test->_get_test_object(
        {
            region_length_U5  => 1,
        }
    ), 'we got another test object';
    ok $new_obj->target_data->{target_start} = 101176328, 'can set target_start';
    ok $new_obj->target_data->{target_end}   = 101176428, 'can set target_end';

    throws_ok {
        !$new_obj->coordinates_for_oligo( 'U5' )
    } qr/Start \d+, greater than or equal to end \d+/, 'throws start greater than end error';
}

sub get_oligo_region_coordinates :  Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->get_oligo_region_coordinates
    } 'can get_oligo_region_coordinates';

    my $oligo_region_file = $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $oligo_region_file )
        , "$oligo_region_file oligo file exists";
}

sub _get_test_object {
    my ( $test, $params ) = @_;

    my $u5_length = $params->{region_length_U5} || 200;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/oligo_regions_ins_del');

    # need oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir              => $dir,
        region_length_U5 => $u5_length,
        design_method    => 'deletion',
    );
}

1;

__END__
