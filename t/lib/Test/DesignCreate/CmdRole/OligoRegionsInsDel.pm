package Test::DesignCreate::CmdRole::OligoRegionsInsDel;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoRegionsInsDel
# DesignCreate::Action::OligoRegionsInsDel ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoRegionsInsDel' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'oligo-regions-ins-del',
        '--dir', $dir->stringify,
        '--target-start', 101176328,
        '--target-end', 101176428,
        '--chromosome', 11,
        '--strand', 1,
        '--design-method', 'deletion',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub coordinates_for_oligo : Tests(16) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->coordinates_for_oligo( 'U5' )
        , 'can call coordinates_for_oligo';

    my $u5_real_start = ( $o->target_start - ( $o->U5_region_offset + $o->U5_region_length ) );
    my $u5_real_end = ( $o->target_start - ( $o->U5_region_offset + 1 ) );
    is $u5_start, $u5_real_start, 'correct start value';
    is $u5_end, $u5_real_end, 'correct end value';

    ok my( $g3_start, $g3_end ) = $o->coordinates_for_oligo( 'G3' )
        , 'can call coordinates_for_oligo';
    my $g3_real_start = ( $o->target_end + ( $o->G3_region_offset + 1 ) );
    my $g3_real_end = ( $o->target_end + ( $o->G3_region_offset + $o->G3_region_length ) );
    is $g3_start, $g3_real_start, 'correct start value';
    is $g3_end, $g3_real_end, 'correct end value';

    # -ve stranded design
    ok $o = $test->_get_test_object( { strand => -1 } ), 'can grab test object';

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

    ok $o = $test->_get_test_object(
        {
            target_start      => 101176328,
            target_end        => 101176428,
            U5_region_length  => 1,
        }
    ), 'we got another test object';

    throws_ok {
        !$o->coordinates_for_oligo( 'U5' )
    } qr/Start \d+, greater than or equal to end \d+/, 'throws start greater than end error';
}

sub get_oligo_region_coordinates :  Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->get_oligo_region_coordinates
    } 'can get_oligo_region_coordinates';

    my $oligo_region_file = $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $oligo_region_file )
        , "$oligo_region_file oligo file exists";

    ok $o = $test->_get_test_object(
        {
            target_start => 101176428,
            target_end   => 101176328,
        }
    ), 'can create another test object';

    throws_ok {
        $o->get_oligo_region_coordinates
    } qr/Target start \d+, greater than target end \d+/
        ,'throws error when target start greater than target end';
}

sub _get_test_object {
    my ( $test, $params ) = @_;

    my $strand = $params->{strand} || 1;
    my $start = $params->{target_start} || 101176328;
    my $end = $params->{target_end} || 101176428;
    my $u5_length = $params->{U5_region_length} || 200;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir              => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        target_start     => $start,
        target_end       => $end,
        chr_name         => 11,
        chr_strand       => $strand,
        U5_region_length => $u5_length,
        design_method    => 'deletion',
    );
}

1;

__END__
