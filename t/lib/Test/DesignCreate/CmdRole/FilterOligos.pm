package Test::DesignCreate::CmdRole::FilterOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::FilterOligos ( through command line )
# DesignCreate::CmdRole::FilterOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FilterOligos' );
}

sub valid_filter_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'filter-oligos',
        '--dir', $o->dir->stringify,
        '--chromosome', 11,
        '--strand', 1,
        '--design-method', 'deletion',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub all_oligos : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->oligo_finder_output_dir->file( 'U5.yaml' )
        ,'can grab U5.yaml file';

    ok $u5_file->remove, 'can remove U5.yaml file';

    throws_ok{
        $o->all_oligos
    } qr/Cannot find file U5\.yaml/
        ,'throws error if missing expected oligo file';

    ok $u5_file->touch, 'can create a empty U5.yaml file';

    throws_ok{
        $o->all_oligos
    } qr/No oligo data in/
        ,'throws error if oligo file is empty';
}

sub check_oligo_length : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_length( $oligo_data ), 'check_oligo_length check passes';
    $oligo_data->{oligo_seq} = 'ATCG';
    ok !$o->check_oligo_length( $oligo_data ), 'check_oligo_length check fails';
}

sub check_oligo_sequence : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    my $oligo_slice = $o->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $o->design_param( 'chr_name' ),
    );

    ok $o->check_oligo_sequence( $oligo_data, $oligo_slice ), 'check_oligo_sequence check passes';
    $oligo_data->{oligo_seq} = 'ATCG';
    ok !$o->check_oligo_sequence( $oligo_data, $oligo_slice ), 'check_oligo_sequence check fails';

    $oligo_data = $oligos_data->[1];
    $oligo_data->{oligo_start} = $oligo_data->{oligo_start} + 1;
    ok !$o->check_oligo_sequence( $oligo_data, $oligo_slice ), 'check_oligo_sequence check fails';
}

sub check_oligo_coordinates : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check passes';
    $oligo_data->{offset} = 123;
    ok !$o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check fails, start';

    $oligo_data = $oligos_data->[1];
    $oligo_data->{oligo_length} = $oligo_data->{oligo_length} + 1;
    ok !$o->check_oligo_coordinates( $oligo_data ), 'check_oligo_coordinates check fails, end';
}

sub check_oligo_specificity : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $oligo_id = 'U5-1';

    lives_ok{
        $o->run_exonerate
    } 'setup test object';

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

sub validate_oligos : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->run_exonerate
    } 'setup test object';

    ok $o->validate_oligos(), 'validate_oligos check passes';

    ok my $new_o = $test->_get_test_object, 'can grab another test object';
    lives_ok{
        $new_o->run_exonerate
    } 'setup test object';

    ok $new_o->all_oligos->{U5} = [], 'delete U5 oligo data';
    throws_ok{
        $new_o->validate_oligos
    } 'DesignCreate::Exception::OligoValidation', 'throws error when missing required valid oligos';

}

sub validate_oligo : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->run_exonerate
    } 'setup test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( 'U5.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->validate_oligo( $oligo_data, 'U5' ), 'validate_oligo check passes';
    ok !$o->validate_oligo( $oligo_data, 'U3' ), 'validate_oligo check fails, wrong oligo type';
    $oligo_data->{offset} = 123;
    ok !$o->validate_oligo( $oligo_data, 'U5' ), 'validate_oligo check fails';
}

sub target_flanking_region_coordinates : Test(8){
    my $test = shift;

    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my( $plus_start, $plus_end ) = $o->target_flanking_region_coordinates
        , 'can call target_flanking_region_coordinates';

    # plus and minus strand designs are symmetric so values should be the same
    my $start = ( 101171328 - 100000 );
    my $end = ( 101181428 + 100000 );

    is $plus_start, $start , 'start is correct';
    is $plus_end, $end , 'end is correct';

    ok $o = $test->_get_test_object( -1 ), 'can grab another test object';

    ok my( $minus_start, $minus_end ) = $o->target_flanking_region_coordinates
        , 'can call target_flanking_region_coordinates';

    is $minus_start, $start, 'start is correct';
    is $minus_end, $end , 'end is correct';
}

sub define_exonerate_target_file : Test(3){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->define_exonerate_target_file
    } 'can define_exonerate_target_file';

    my $target_file = $o->exonerate_oligo_dir->file( 'exonerate_target.fasta' );
    ok $o->exonerate_oligo_dir->contains( $target_file ), 'file has been created';
}

sub define_exonerate_query_file : Test(3){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->define_exonerate_query_file
    } 'can define_exonerate_query_file';

    my $query_file = $o->exonerate_oligo_dir->file( 'exonerate_query.fasta' );
    ok $o->exonerate_oligo_dir->contains( $query_file ), 'file has been created';
}

sub run_exonerate : Test(6){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

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
    $o->define_exonerate_query_file;

    throws_ok{
        $o->run_exonerate
    } qr/No output from exonerate/, 'throws error when no matches found';
}

sub output_validated_oligos : Test(7){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->run_exonerate;
        $o->validate_oligos;
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
    my ( $test, $strand ) = @_;
    $strand //= 1;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir;
    if ( $strand == 1 ) {
        $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/filter_oligos_data_plus');
    }
    elsif ( $strand == -1 ) {
        $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/filter_oligos_data_minus');
    }

    # need 4 aos oligo files to test against, in oligo_finder_output dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::Role::EnsEMBL' ] );
    return $metaclass->new_object( dir => $dir);
}

1;

__END__
