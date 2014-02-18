package Test::DesignCreate::CmdRole::OligoPairRegionsGibsonDel;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoPairRegionsGibsonDel
# DesignCreate::Action::OligoPairRegionsGibsonDel ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoPairRegionsGibsonDel' );
}

sub valid_run_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    #note: small chance with new ensembl build that we will need
    #      to update the exon id
    my @argv_contents = (
        'oligo-pair-regions-gibson-del',
        '--dir', $o->dir->stringify,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub five_prime_region_start_and_end : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok my $target_start = $o->target_data->{target_start}, 'can grab target_start';
    ok my $target_end = $o->target_data->{target_end}, 'can grab target_end';

    lives_ok {
        $o->calculate_pair_region_coordinates
    } 'can call calculate_pair_region_coordinates';

    is $o->five_prime_region_start, $target_end + 200
        , 'five_prime_region_start value correct -ve strand';
    is $o->five_prime_region_end, $target_end + 200 + 100 + 500 + 1000
        , 'five_prime_region_end value correct -ve strand';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj = $metaclass->new_object( dir => $o->dir );

    ok $new_obj->target_data->{chr_strand} = 1, 'override strand 1';
    lives_ok {
        $new_obj->calculate_pair_region_coordinates
    } 'can call calculate_pair_region_coordinates';

    is $new_obj->five_prime_region_start, $target_start - ( 200 + 100 + 500 + 1000 )
        , 'five_prime_region_start value correct +ve strand';
    is $new_obj->five_prime_region_end, $target_start - 200
        , 'five_prime_region_end value correct +ve strand';
}

sub three_prime_region_start_and_end : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok my $target_start = $o->target_data->{target_start}, 'can grab target_start';
    ok my $target_end = $o->target_data->{target_end}, 'can grab target_end';

    lives_ok {
        $o->calculate_pair_region_coordinates
    } 'can call calculate_pair_region_coordinates';

    is $o->three_prime_region_start, $target_start - ( 100 + 100 + 1000 + 500 )
        , 'three_prime_region_start value correct -ve strand';
    is $o->three_prime_region_end, $target_start - 100
        , 'three_prime_region_end value correct -ve strand';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj = $metaclass->new_object( dir => $o->dir );

    ok $new_obj->target_data->{chr_strand} = 1, 'override strand 1';
    lives_ok {
        $new_obj->calculate_pair_region_coordinates
    } 'can call calculate_pair_region_coordinates';

    is $new_obj->three_prime_region_start, $target_end + 100
        , 'three_prime_region_start value correct +ve strand';
    is $new_obj->three_prime_region_end, $target_end + 100 + 100 + 500 + 1000
        , 'three_prime_region_end value correct +ve strand';
}

sub get_oligo_pair_region_coordinates : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok delete $o->target_data->{chr_strand}, 'can delete target strand data';
    throws_ok {
        $o->get_oligo_pair_region_coordinates
    } qr/No target value for: chr_strand/
        , 'throws error when missing target data';

    ok $o->target_data->{chr_strand} = -1, 'can set target strand data';

    lives_ok {
        $o->get_oligo_pair_region_coordinates
    } 'can get_oligo_pair_region_coordinates';

    ok exists $o->oligo_region_coordinates->{three_prime}{start}, 'we have a three_prime region start value';
    ok exists $o->oligo_region_coordinates->{three_prime}{end}, 'we have a three_prime region end value';
    ok exists $o->oligo_region_coordinates->{five_prime}{start}, 'we have a five_prime region start value';
    ok exists $o->oligo_region_coordinates->{five_prime}{end}, 'we have a five_prime region end value';

    my $oligo_region_file = $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $oligo_region_file )
        , "$oligo_region_file oligo file exists";

}

sub _get_test_object {
    my ( $test, $params ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/oligo_pair_regions_gibson');

    # need oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object( dir => $dir );
}

1;

__END__
