package Test::DesignCreate::CmdRole::FindOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Bio::Seq;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use FindBin;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::FindOligos ( through command line )
# DesignCreate::CmdRole::FindOligos, most of its work is done by:
# Note, DesignCreate::Role::AOS is already tested by RunAOS

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FindOligos' );
}

sub valid_find_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'find-oligos',
        '--dir', $o->dir->stringify,
        '--chromosome', 11,
        '--design-method', 'deletion',
    );

    note('############################################');
    note('Following test may take a while to finish...');
    note('############################################');
    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

sub create_aos_query_file : Test(13) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->create_aos_query_file
    } 'can create_aos_query_file';

    ok my $seq_in = Bio::SeqIO->new( -fh => $o->query_file->openr, -format => 'fasta' )
        , '.. we have a Bio::SeqIO object';

    while ( my $seq = $seq_in->next_seq ) {
        like $seq->display_id, qr/^(U|D|G)(3|5):\d+-\d+$/, 'seq display id is expected';
    }

    # remove required oligo file
    lives_ok{
        $o->oligo_target_regions_dir->file( 'U5.fasta' )->remove
    } 'can remove U5.fasta target region file';

    throws_ok{
        $o->create_aos_query_file
    } qr/Cannot find file/
        , '.. now throws error about missing file';

    ok $o = $test->_get_test_object, 'can grab another test object';
    ok my $u5_file = $o->oligo_target_regions_dir->file( 'U5.fasta' ), 'grab U5 region file';

    lives_ok {
        my @u5_data_lc = map{ lc( $_) } $u5_file->slurp;
        $u5_file->spew( \@u5_data_lc );
    } 'can lower-case the U5 oligo region sequence';

    throws_ok{
        $o->create_aos_query_file
    } qr/Following oligo regions are completely repeat masked: U5/
        , '.. throws error about completely repeat masked oligo regions';
}

sub define_target_file : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->define_target_file
    } 'can call define_target_file';

    is $o->target_file->basename, '11.fasta', '.. have correct target file';

    lives_ok{
        $o->define_target_file
    } 'can call define_target_file again';
    is $o->target_file->basename, '11.fasta', '.. target file should stay the same';

    my $metaclass = $test->get_test_object_metaclass();
    $o = $metaclass->new_object(
        dir                 => $o->dir,
        base_chromosome_dir => tempdir( TMPDIR => 1, CLEANUP => 1 ),
    );

    throws_ok{
        $o->define_target_file
    } qr/Cannot find file/
        ,'throws error if we do not have a chromosome target file';
}

sub check_aos_output : Test(6) {
    my $test = shift;

    ok my $o = $test->_get_test_object, 'can grab test object';
    ok my $aos_output_dir = $o->aos_output_dir, 'grab aos_output_dir';

    lives_ok {
        $aos_output_dir->file( $_ . '.yaml' )->touch for qw( G5 U5 D3 G3 );
    } 'can create test oligo output files';

    lives_ok{
        $o->check_aos_output
    } 'can call check_aos_output';

    ok $aos_output_dir->file( 'U5.yaml' )->remove, 'can remove U5 yaml file';

    throws_ok{
        $o->check_aos_output
    } qr/AOS was unable to find any of the following oligos: U5/
        , 'Throws correct error when missing oligos';
}

sub check_masked_seq : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->check_masked_seq( 'ATCG', 'U5' )
    } 'can call check_aos_output';

    ok !$o->has_repeat_masked_oligo_regions, 'no repeat masked oligo regions';

    lives_ok{
        $o->check_masked_seq( 'atcg', 'U5' )
    } 'can call check_aos_output';

    ok $o->has_repeat_masked_oligo_regions, 'has repeat masked oligo regions';
    is_deeply $o->repeat_masked_oligo_regions, [ 'U5' ], 'correct repeat masked oligo region data';
}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/find_oligos_data');

    # need 4 oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object( dir => $dir );
}

1;

__END__
