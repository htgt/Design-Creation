package Test::DesignCreate::CmdRole::RunAOS;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use FindBin;
use Bio::Seq;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::RunAOS;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::RunAOS ( through command line )
# DesignCreate::CmdRole::RunAOS, most of its work is done by:
# DesignCreate::Role::AOS

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::RunAOS' );
}

sub valid_run_aos_cmd : Test(3) {
    my $test = shift;

    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'run-aos',
        '--dir', $dir->dirname,
        '--target-file', get_test_data_file('run_aos_target_file.fasta'),
        '--query-file', get_test_data_file('run_aos_query_file.fasta'),
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

sub run_aos_scripts : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'we got a test object';

    lives_ok{
        $o->run_aos_scripts
    } 'Can run_aos_script1';

    my $aos_work_dir = $o->aos_work_dir;
    for my $filename ( qw( target.fa query.fa oligo_fasta ) ) {
        my $file = $aos_work_dir->file( $filename );
        ok $aos_work_dir->contains( $file ), "File $filename has been created";
    }

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 0 )->absolute;
    $o = $test->test_class->new(
        dir         => $dir,
        query_file  => get_test_data_file('run_aos_broken_query_file.fasta'),
        target_file => get_test_data_file('run_aos_target_file.fasta'),
    );

    throws_ok{
        $o->run_aos_scripts
    } qr/Problem running aos scripts, check log files/
        , 'Throws error if aos scripts fail to run properly';
}

sub parse_oligo_seq : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'we got a test object';

    my $good_seq = Bio::Seq->new( -seq => 'ATCGA', -id => 'U5:1000-1004_10' );
    ok my $oligo_data = $o->parse_oligo_seq( $good_seq ), 'Can parse_oligo_seq';

    is $oligo_data->{offset}, 10, '.. offset is correct';
    is $oligo_data->{target_region_start}, 1000, '.. target_region_start is correct';
    is $oligo_data->{target_region_end}, 1004, '.. target_region_end is correct';
    is $oligo_data->{oligo_start}, 1000 + 10, '.. oligo_start is correct';
    is $oligo_data->{oligo_end}, ( (1000 + 10) + ( 50 -1 ) ), '.. oligo_end is correct';
    is $oligo_data->{oligo_seq}, 'ATCGA', '.. oligo_seq is correct';
    is $oligo_data->{oligo}, 'U5', '.. oligo is correct';

    my $bad_seq = Bio::Seq->new( -seq => 'ATCGA', -id => 'U5' );
    ok !$o->parse_oligo_seq( $bad_seq ), 'Can parse_oligo_seq';
}

sub parse_aos_output : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->run_aos_scripts;
        $o->parse_aos_output;
    } 'Can parse_aos_output';
    ok $o->has_oligos, '.. and we have oligos';
}

sub create_oligo_files : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->run_aos_scripts;
        $o->parse_aos_output;
        $o->create_oligo_files;
    } 'Can create_oligo_files';

    my $file = $o->aos_output_dir->file( 'U5.yaml' );
    ok $o->aos_output_dir->contains( $file ), "File U5.yaml has been created";

    #no oligos
    ok $o = $test->_get_test_object, 'can grab test object';
    ok !$o->has_oligos, '.. and we have no oligos';
    throws_ok{
        $o->create_oligo_files
    } qr/No oligos found/
        , 'Can not create oligo files if we have not oligos';
}

sub get_test_data_file {
    my ( $filename ) = @_;
    my $data_dir = dir($FindBin::Bin)->subdir('test_data/run_aos_data/');
    my $file = $data_dir->file($filename);

    return $file->stringify;
}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    return $test->test_class->new(
        dir         => $dir,
        query_file  => get_test_data_file('run_aos_query_file.fasta'),
        target_file => get_test_data_file('run_aos_target_file.fasta'),
    );
}

1;

__END__
