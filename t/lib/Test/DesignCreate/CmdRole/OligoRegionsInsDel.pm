package Test::DesignCreate::CmdRole::OligoRegionsInsDel;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::OligoRegionsInsDel;
use DesignCreate::Cmd;

# Testing
# DesignCreate::CmdRole::OligoRegionsInsDel
# DesignCreate::Action::OligoRegionsInsDel ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::OligoRegionsInsDel' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'oligo-regions-ins-del',
        '--dir', $dir->dirname,
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

sub get_oligo_region_coordinates : Tests(16) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $u5_start, $u5_end ) = $o->get_oligo_region_coordinates( 'U5' )
        , 'can call get_oligo_region_coordinates';

    my $u5_real_start = ( $o->target_start - ( $o->U5_region_offset + $o->U5_region_length ) );
    my $u5_real_end = ( $o->target_start - ( $o->U5_region_offset + 1 ) );
    is $u5_start, $u5_real_start, 'correct start value';
    is $u5_end, $u5_real_end, 'correct end value';

    ok my( $g3_start, $g3_end ) = $o->get_oligo_region_coordinates( 'G3' )
        , 'can call get_oligo_region_coordinates';
    my $g3_real_start = ( $o->target_end + ( $o->G3_region_offset + 1 ) );
    my $g3_real_end = ( $o->target_end + ( $o->G3_region_offset + $o->G3_region_length ) );
    is $g3_start, $g3_real_start, 'correct start value';
    is $g3_end, $g3_real_end, 'correct end value';

    # -ve stranded design
    ok $o = $test->_get_test_object( -1 ), 'can grab test object';

    ok my( $d3_start, $d3_end ) = $o->get_oligo_region_coordinates( 'D3' )
        , 'can call get_oligo_region_coordinates';

    #because these -ve and +ve strand deletion designs are symmetric the coordinates:
    #   U5 region on the +ve design should be the same as D3 region on the -ve design
    #   G5 region on the +ve design should be the same as G3 region on the -ve design

    is $d3_start, $u5_real_start, 'correct start value';
    is $d3_end, $u5_real_end, 'correct end value';

    ok my( $g5_start, $g5_end ) = $o->get_oligo_region_coordinates( 'G5' )
        , 'can call get_oligo_region_coordinates';

    is $g5_start, $g3_real_start, 'correct start value';
    is $g5_end, $g3_real_end, 'correct end value';

    ok $o = $test->test_class->new(
        dir               => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        target_start      => 101176328,
        target_end        => 101176428,
        chr_name          => 11,
        chr_strand        => 1,
        U5_region_length  => 1,
    ), 'we got a object';

    throws_ok {
        !$o->get_oligo_region_coordinates( 'U5' )
    } qr/Start \d+, greater than or equal to end \d+/, 'throws start greater than end error';
}

sub build_oligo_target_regions : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->build_oligo_target_regions
    } 'can build_oligo_target_regions';

    for my $oligo ( qw( G5 U5 D3 G3 ) ) {
        my $oligo_file = $o->oligo_target_regions_dir->file( $oligo . '.fasta' );
        ok $o->oligo_target_regions_dir->contains( $oligo_file ), "$oligo oligo file exists";
    }
}

sub _get_test_object {
    my ( $test, $strand ) = @_;
    $strand //= 1;

    return $test->test_class->new(
        dir          => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        target_start => 101176328,
        target_end   => 101176428,
        chr_name     => 11,
        chr_strand   => $strand,
    );
}

1;

__END__
