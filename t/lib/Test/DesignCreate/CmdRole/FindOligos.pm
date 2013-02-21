package Test::DesignCreate::CmdRole::FindOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Bio::Seq;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use FindBin;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::FindOligos;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::FindOligos ( through command line )
# DesignCreate::CmdRole::FindOligos, most of its work is done by:
# Note, DesignCreate::Role::AOS is already tested by RunAOS

use Smart::Comments;

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::FindOligos' );
}

sub valid_find_oligos_cmd : Test(2) {
    my $test = shift;

    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'find-oligos',
        '--dir', $o->dir->stringify,
        '--chromosome', 11,
    );

    note('############################################');
    note('Following test may take a while to finish...');
    note('############################################');
    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

sub create_aos_query_file : Test(9) {
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
    } qr/Can't find U5 target region file:/
        , '.. now throws error about missing file';

}

sub define_target_file : Test(no_plan) {
    my $test = shift;

    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->define_target_file
    } 'can call define_target_file';

    is $o->target_file->basename, '11.fasta', '.. have correct target file';
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
    } qr/Can't find U5 oligo file/, 'Throws correct error when missing oligo file';

}

sub get_test_data_file {
    my ( $filename ) = @_;

    my $data_dir = dir($FindBin::Bin)->subdir('test_data');

    my $file = $data_dir->file($filename);

    #if ( $filename =~ m/\.yaml$/ and not $opts{raw} ) {
        #return LoadFile($file);
    #}

    return $file;
}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/find_oligos_data');

    # need 4 oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify . '/oligo_target_regions' );

    return $test->test_class->new(
        dir      => $dir,
        chr_name => 11,
    );
}

1;

__END__
