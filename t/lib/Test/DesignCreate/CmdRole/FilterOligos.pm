package Test::DesignCreate::CmdRole::FilterOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::FilterOligos;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::FilterOligos ( through command line )
# DesignCreate::CmdRole::FilterOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::FilterOligos' );
}

sub valid_filter_oligos_cmd : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'filter-oligos',
        '--dir', $o->dir->stringify,
        '--chromosome', 11,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
}

sub check_oligo_length : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->aos_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_length( $oligo_data ), 'check_oligo_length check passes';
    $oligo_data->{oligo_seq} = 'ATCG';
    ok !$o->check_oligo_length( $oligo_data ), 'check_oligo_length check fails';
}

sub check_oligo_sequence : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->aos_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_sequence( $oligo_data ), 'check_oligo_sequence check passes';
    $oligo_data->{oligo_seq} = 'ATCG';
    ok !$o->check_oligo_sequence( $oligo_data ), 'check_oligo_sequence check fails';

    $oligo_data = $oligos_data->[1];
    $oligo_data->{oligo_start} = $oligo_data->{oligo_start} + 1;
    ok !$o->check_oligo_sequence( $oligo_data ), 'check_oligo_sequence check fails';
}

sub check_oligo_coordinates : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->aos_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check passes';
    $oligo_data->{offset} = 123;
    ok !$o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check fails, start';

    $oligo_data = $oligos_data->[1];
    $oligo_data->{oligo_length} = $oligo_data->{oligo_length} + 1;
    ok !$o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check fails, end';
}

sub validate_oligo : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->aos_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->validate_oligo( $oligo_data, 'U5' ), 'validate_oligo check passes';
    ok !$o->validate_oligo( $oligo_data, 'U3' ), 'validate_oligo check fails, wrong oligo type';
    $oligo_data->{offset} = 123;
    ok !$o->validate_oligo( $oligo_data, 'U5' ), 'validate_oligo check fails';
}

sub validate_oligos_of_type : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligo_file = $o->aos_output_dir->file( 'U5.yaml' ), 'can get U5.yaml oligo file';
    ok $o->validate_oligos_of_type( $oligo_file, 'U5' ), 'validate_oligo check passes';

    my $empty_file = $o->aos_output_dir->file( 'test.yaml' );
    $empty_file->touch;
    ok !$o->validate_oligos_of_type( $empty_file, 'U5' ), 'validate_oligo check fails, empty oligo file';

    ok !$o->validate_oligos_of_type( $oligo_file, 'U3' )
        ,'validate_oligo check fails, no valid oligos of type U3';
}

sub validate_oligos : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok $o->validate_oligos(), 'validate_oligos check passes';

    ok $o->aos_output_dir->file( 'U5.yaml' )->remove, 'can remove U5.yaml file';

    throws_ok{
        $o->validate_oligos()
    } qr/Can't find U5 oligo file/, 'throws error when no U5.yaml file';

    $o->aos_output_dir->file( 'U5.yaml' )->touch;

    throws_ok{
        $o->validate_oligos()
    } qr/No valid U5 oligos/, 'throws error when empty U5.yaml file';

}

sub target_flanking_region_coordinates : Test(5){
    my $test = shift;

    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    ok my( $start, $end ) = $o->target_flanking_region_coordinates
        , 'can call target_flanking_region_coordinates';

    is $start, ( 101171328 - 100000 ), 'start is correct';
    is $end, ( 101181428 + 100000 ), 'end is correct';

}

sub define_exonerate_target_file : Test(4){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    lives_ok{
        $o->define_exonerate_target_file
    } 'can define_exonerate_target_file';

    my $target_file = $o->exonerate_oligo_dir->file( 'exonerate_target.fasta' );
    ok $o->exonerate_oligo_dir->contains( $target_file ), 'file has been created';
}

sub define_exonerate_query_file : Test(4){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    lives_ok{
        $o->define_exonerate_query_file
    } 'can define_exonerate_query_file';

    my $query_file = $o->exonerate_oligo_dir->file( 'exonerate_query.fasta' );
    ok $o->exonerate_oligo_dir->contains( $query_file ), 'file has been created';
}

sub run_exonerate : Test(7){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    lives_ok{
        $o->run_exonerate
    } 'can run_exonerate';

    my $query_file = $o->exonerate_oligo_dir->file( 'exonerate_output.log' );
    ok $o->exonerate_oligo_dir->contains( $query_file ), 'log file has been created';

    ok $o = $test->_get_test_object, 'can grab another test object';
    lives_ok{
        my $test_target_file = $o->exonerate_oligo_dir->file( 'test_target_file.fasta' );
        $test_target_file->touch;
        $test_target_file->spew( [ ( ">test\n", 'ATGTGTATA' ) ] );
        $o->exonerate_target_file( $test_target_file->absolute );
    } 'Setup test target file';
    $o->validate_oligos;
    $o->define_exonerate_query_file;

    throws_ok{
        $o->run_exonerate
    } qr/No output from exonerate/, 'throws error when no matches found';
}

sub check_oligo_specificity : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $oligo_id = 'U5-1';

    ok $o->check_oligo_specificity( $oligo_id, { exact_matches => 1, hits => 1 } )
        , 'returns true for one exact match, one hit';

    ok !$o->check_oligo_specificity( $oligo_id, {} ), 'return false if no match_info';
    ok !$o->check_oligo_specificity( $oligo_id, { exact_matches => 2, hits => 2 } )
        , 'returns false for two exact matchs, two hits';
    ok !$o->check_oligo_specificity( $oligo_id, { exact_matches => 0, hits => 0 } )
        , 'returns false for zero exact match, zero hit';
    ok !$o->check_oligo_specificity( $oligo_id, { exact_matches => 1, hits => 2 } )
        , 'returns false for one exact match, two hits';

}

sub filter_out_non_specific_oligos : Test(3){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
        $o->run_exonerate;
    } 'setup test object';

    lives_ok{
        $o->filter_out_non_specific_oligos( )
    } 'can filter_out_non_specific_oligos';
}

sub have_required_validated_oligos : Test(5){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
        $o->run_exonerate;
        $o->filter_out_non_specific_oligos;
    } 'setup test object';

    ok $o->have_required_validated_oligos, 'have_required_validated_oligos returns true';

    ok delete $o->validated_oligos->{U5}, 'delete U5 validated oligos';
    throws_ok{
        $o->have_required_validated_oligos
    } qr/No valid U5 oligos/, 'throws error when missing required valid oligos';
}

sub output_validated_oligos : Test(7){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
        $o->run_exonerate;
        $o->filter_out_non_specific_oligos;
    } 'setup test object';

    lives_ok{
        $o->output_validated_oligos
    } 'can output_validated_oligos';

    for my $oligo ( qw( G5 U5 D3 G3 ) ) {
        my $oligo_file = $o->validated_oligo_dir->file( $oligo . '.yaml' );
        ok $o->validated_oligo_dir->contains( $oligo_file )
            , "validated oligo dir contains $oligo yaml file";
    }

}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/filter_oligos_data');

    # need 4 aos oligo files to test against, in aos_output dir
    dircopy( $data_dir->stringify, $dir->stringify . '/aos_output' );

    return $test->test_class->new(
        dir        => $dir,
        chr_name   => 11,
        chr_strand => 1,
    );
}

1;

__END__