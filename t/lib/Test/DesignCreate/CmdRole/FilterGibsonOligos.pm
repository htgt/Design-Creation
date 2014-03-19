package Test::DesignCreate::CmdRole::FilterGibsonOligos;
use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use JSON;
use FindBin;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::Cmd::Step::FilterGibsonOligos ( through command line )
# DesignCreate::CmdRole::FilterGibsonOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FilterGibsonOligos' );
}

sub run_bwa : Test(startup => 2) {
    my $test = shift;

    note( 'Run bwa once and startup and store data to save on time' );
    ok my $o = $test->_get_test_object, 'can grab test object';
    note( 'Running bwa may take some time' );
    lives_ok { $o->run_bwa } 'can call run_bwa';

    $test->{bwa_data} = $o->bwa_matches;
}

sub valid_filter_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'filter-gibson-oligos',
        '--dir', $o->dir->stringify,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub check_oligo_length : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( '5F.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    ok $o->check_oligo_length( $oligo_data ), 'check_oligo_length check passes';
    $oligo_data->{oligo_seq} = 'ATCG';
    ok !$o->check_oligo_length( $oligo_data ), 'check_oligo_length check fails';
}

sub check_oligo_sequence : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( '5F.yaml' )->stringify )
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

sub check_oligo_not_near_exon : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( '3F.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[0];

    my $oligo_slice = $o->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $o->design_param( 'chr_name' ),
    );

    ok $o->check_oligo_not_near_exon( $oligo_data, $oligo_slice )
        , 'check_oligo_not_near_exon check passes';

    # moving slice back 50 bases takes it close enough to a exon
    my $oligo_slice_modified = $o->get_slice(
        $oligo_data->{oligo_start} - 50,
        $oligo_data->{oligo_end} - 50,
        $o->design_param( 'chr_name' ),
    );
    ok !$o->check_oligo_not_near_exon( $oligo_data, $oligo_slice_modified )
        , 'check_oligo_not_near_exon check fails';
}

sub validate_oligo : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos_data = LoadFile( $o->oligo_finder_output_dir->file( '5R.yaml' )->stringify )
        , 'can load oligo yaml data file';
    my $oligo_data = $oligos_data->[1];

    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );

    ok $o->validate_oligo( $oligo_data, '5R' ), 'validate_oligo check passes';
    ok !$o->validate_oligo( $oligo_data, 'U3' ), 'validate_oligo check fails, wrong oligo type';
    $oligo_data->{oligo_seq} = 'AAAATTTT';
    ok !$o->validate_oligo( $oligo_data, '5R' ), 'validate_oligo check fails';
}

sub validate_oligos : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );

    ok $o->validate_oligos(), 'validate_oligos check passes';

    ok my $new_o = $test->_get_test_object, 'can grab another test object';
    # setup bwa match data to save time
    $new_o->bwa_matches( $test->{bwa_data} );

    lives_ok { $new_o->all_oligos } 'can call all_oligos on test object';
    ok $new_o->all_oligos->{'5F'} = {}, 'delete 5F oligo data';
    throws_ok{
        $new_o->validate_oligos
    } 'DesignCreate::Exception::OligoValidation', 'throws error when missing required valid oligos';

}

sub output_validated_oligos : Test(9){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    lives_ok{
        $o->output_validated_oligos
    } 'can output_validated_oligos';

    for my $oligo ( qw( 5F 5R EF ER 3F 3R ) ) {
        my $oligo_file = $o->validated_oligo_dir->file( $oligo . '.yaml' );
        ok $o->validated_oligo_dir->contains( $oligo_file )
            , "validated oligo dir contains $oligo yaml file";
    }

}

sub validate_oligo_pairs : Tests(9){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );

    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    for my $region ( qw( five_prime exon three_prime ) ) {
        ok !$o->region_has_oligo_pairs($region),
            "do not have valid pair for $region region";
    }

    lives_ok{
        $o->validate_oligo_pairs
    } 'can call validate_oligo_pairs';

    for my $region ( qw( five_prime exon three_prime ) ) {
        ok $o->region_has_oligo_pairs($region),
            "have valid pair for $region region";
    }
}

sub output_valid_oligo_pairs : Tests(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );
    lives_ok{
        $o->validate_oligos;
        $o->validate_oligo_pairs;
    } 'setup test object';

    lives_ok{
        $o->output_valid_oligo_pairs;
    } 'can output_valid_oligo_pairs';

    for my $region ( qw( exon five_prime three_prime ) ) {
        my $oligo_pair_file = $o->validated_oligo_dir->file( $region . '_oligo_pairs.yaml' );
        ok $o->validated_oligo_dir->contains( $oligo_pair_file )
            , "validated oligo dir contains $region oligo pair yaml file";
    }

    ok delete $o->validated_oligo_pairs->{exon}, 'can delete valid exon oligo pairs';

    throws_ok{
        $o->output_valid_oligo_pairs
    } 'DesignCreate::Exception::OligoPairRegionValidation'
        ,'throws error when missing oligo pairs from one or more regions';
}

sub update_candidate_oligos_after_validation : Tests(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    # setup bwa match data to save time
    $o->bwa_matches( $test->{bwa_data} );
    lives_ok{
        $o->validate_oligos;
        $o->validate_oligo_pairs;
    } 'setup test object';

    lives_ok{
        $o->update_candidate_oligos_after_validation
    } 'can output_validated_oligos';

    my $mock_api = $o->lims2_api;
    $mock_api->called_ok( 'PUT', 'called PUT on lims2_api' );

    $mock_api->called_args_pos_is( 1, 2, 'design_attempt',
        'we are sending design_attempt as the first argument to PUT' );
    ok my $update_data = $mock_api->call_args_pos( 1, 3 ), 'can grab design attempt update data';
    ok exists $update_data->{candidate_oligos},
        '.. and we are trying to update the candidate_oligos column';

    ok my $candidate_oligo_data = decode_json( $update_data->{candidate_oligos} ),
        'can decode candidate oligo json data';
    is_deeply [ sort keys %{$candidate_oligo_data} ], [ '3F', '3R', '5F', '5R', 'EF', 'ER' ],
        'candidate oligo data hash has correct keys';
}

sub _get_test_object {
    my ( $test ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/filter_gibson_oligos_data_minus');

    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::Role::EnsEMBL' ] );
    return $metaclass->new_object(
        dir                     => $dir,
        lims2_api               => $test->get_mock_lims2_api,
        exon_check_flank_length => 100,
        persist                 => 1,
    );
}

1;

__END__
