package Test::DesignCreate::CmdRole::PickGapOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::PickGapOligos;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::PickGapOligos ( through command line )
# DesignCreate::CmdRole::PickGapOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::PickGapOligos' );
}

sub valid_pick_gap_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'pick-gap-oligos',
        '--dir', $o->dir->stringify,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub generate_tiled_oligo_seqs : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->generate_tiled_oligo_seqs
    } 'can run generate_tiled_oligo_seqs';

    ok $o->tiled_oligo_seqs, 'we have hash of tiled oligo seqs';

    ok $o = $test->_get_test_object, 'can grab another test object';
    ok $o->validated_oligo_dir->file( 'G3.yaml' )->remove, 'remove G3.yaml oligo file';
    throws_ok{
        $o->generate_tiled_oligo_seqs
    } qr/Can not find file/
        ,'throws error if no G3.yaml file';

    ok $o = $test->_get_test_object, 'can grab another test object';
    ok $o->validated_oligo_dir->file( 'G5.yaml' )->remove, 'remove G5.yaml oligo file';
    throws_ok{
        $o->generate_tiled_oligo_seqs
    } qr/Can not find file/
        ,'throws error if no G5.yaml file';

}

sub tile_oligo_seq : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->tile_oligo_seq( { oligo_seq => 'AAAAAAATG', id => 'G5-1' } )
    } 'can call tile_oligo_seq';

    is_deeply $o->tiled_oligo_seqs, {
        AAAAAA => { 'G5-1' => 2 },
        AAAAAT => { 'G5-1' => 1 },
        AAAATG => { 'G5-1' => 1 },
    }, 'we get expected tiled oligo seqs hash';
}

sub find_oligos_with_matching_seqs : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->generate_tiled_oligo_seqs
    } 'setup object ok';

    lives_ok{
        $o->find_oligos_with_matching_seqs
    } 'can call find_oligos_with_matching_seqs';

    ok $o->matching_oligos, 'we have matching_oligos hash';

    ok $o = $test->_get_test_object, 'can grab another test object';

    lives_ok{
        $o->tile_oligo_seq( { oligo_seq => 'AAAAAAATG', id => 'G5-1' } );
        $o->tile_oligo_seq( { oligo_seq => 'TGAAAAAAA', id => 'G3-2' } );
    } 'can call tile_oligo_seq';

    lives_ok{
        $o->find_oligos_with_matching_seqs
    } 'can call find_oligos_with_matching_seqs';

    is_deeply $o->matching_oligos, {
        'G5-1' => { 'G3-2' => 1 }
    }, 'expected matching hash';

}

sub get_gap_oligo_pairs : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->generate_tiled_oligo_seqs;
        $o->find_oligos_with_matching_seqs;
    } 'setup object ok';

    lives_ok{
        $o->get_gap_oligo_pairs
    } 'can call get_gap_oligo_pairs';

    ok $o->matching_oligos, 'populated matching_oligos hash';

    # Need to create fresh test object here to fill in g oligo data 
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    ok $o = $test->test_class->new(
        dir            => $dir,
        g5_oligos_data => { 'G5-1' => 1 },
        g3_oligos_data => { 'G3-2' => 1, 'G3-3' => 1 },
    ), 'can create another test object';

    lives_ok{
        $o->tile_oligo_seq( { oligo_seq => 'AAAAAAATG', id => 'G5-1' } );
        $o->tile_oligo_seq( { oligo_seq => 'TGAAAAAAA', id => 'G3-2' } );
        $o->tile_oligo_seq( { oligo_seq => 'TTTTTTTTT', id => 'G3-3' } );
        $o->find_oligos_with_matching_seqs;
        $o->get_gap_oligo_pairs;
    } 'setup test object';

    is_deeply $o->oligo_pairs, [
        { G5 => 'G5-1', G3 => 'G3-3' }
    ], 'have expected matching_oligos data'; 

}

sub create_oligo_pair_file : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    throws_ok{
        $o->create_oligo_pair_file
    } qr/No suitable gap oligo pairs found/
        ,'throws error when we have no gap oligo pairs';

    lives_ok{
        $o->generate_tiled_oligo_seqs;
        $o->find_oligos_with_matching_seqs;
        $o->get_gap_oligo_pairs;
    } 'setup object ok';

    lives_ok{
        $o->create_oligo_pair_file
    } 'can call create_oligo_pair_file';

    my $oligo_pair_file = $o->validated_oligo_dir->file('gap_oligo_pairs.yaml');
    ok $o->validated_oligo_dir->contains( $oligo_pair_file ), 'created oligo pair file';

}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/pick_gap_oligos');

    dircopy( $data_dir->stringify, $dir->stringify . '/validated_oligos' );

    return $test->test_class->new( dir => $dir );
}

1;

__END__
