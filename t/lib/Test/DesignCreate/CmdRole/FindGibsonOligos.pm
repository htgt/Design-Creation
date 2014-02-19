package Test::DesignCreate::CmdRole::FindGibsonOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use FindBin;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::FindGibsonOligos ( through command line )
# DesignCreate::CmdRole::FindGibsonOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FindGibsonOligos' );
}

sub valid_find_gibson_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'find-gibson-oligos',
        '--dir', $o->dir->stringify,
        '--repeat-mask-class' , 'trf',
        '--repeat-mask-class' , 'dust',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

sub find_oligos : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->find_oligos
    } 'can call find_oligos';

    ok my $new_o = $test->_get_test_object( 1 ), 'can grab test object';
    throws_ok{
        $new_o->find_oligos
    } 'DesignCreate::Exception'
        , 'throws error when unable to find primers for all regions';
}

sub run_primer3 : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->run_primer3
    } 'can call run_primer3';

    for my $region ( qw( exon five_prime three_prime ) ) {
        ok exists $o->primer3_results->{$region}, "we have results for $region region";
    }

    ok my $new_o = $test->_get_test_object( 1 ), 'can grab test object';

    throws_ok{
        $new_o->run_primer3
    } 'DesignCreate::Exception::Primer3FailedFindOligos'
        , 'throws error when no primer pairs can be found for region';

}

sub build_region_slice : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    throws_ok{
        $o->_build_region_slice( 'foo' )
    } qr/Unable to find coordinates for foo region/
        , 'throws error with unknown region name';

    ok my $exon_slice = $o->_build_region_slice( 'exon' ), 'can build exon region slice';
    is $exon_slice->strand, 1, 'slice is on +ve strand';

    ok $o->set_param( 'chr_strand', -1 ), 'can set strand of design to 1';
    ok $exon_slice = $o->_build_region_slice( 'exon' ), 'can build exon region slice';
    is $exon_slice->strand, -1, 'slice is on -ve strand';
}

sub build_primer3_sequence_target_string : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    throws_ok{
        $o->build_primer3_sequence_target_string( 'foo' )
    } qr/Details for foo region do not exist/
        ,'throws error for unknown region';

    ok my $exon_target_string = $o->build_primer3_sequence_target_string( 'exon' )
        , 'can build target string for exon region';
    is $exon_target_string, '100,1416', '.. and target string is correct';

    ok my $five_prime_target_string = $o->build_primer3_sequence_target_string( 'five_prime' )
        , 'can build target string for five_prime region';
    is $five_prime_target_string, '500,1000', '.. and target string is correct';
}

sub create_oligo_files : Test(13) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    throws_ok{
        $o->create_oligo_files
    } qr/No oligos found/, 'throws error if we do not have oligos';

    lives_ok{
        $o->run_primer3;
        $o->parse_primer3_results;
    } 'can run setup to produce oligos';

    lives_ok{
        $o->create_oligo_files
    } 'can call create_oligo_files when we have some oligos from primer3';

    for my $oligo ( qw( 5F 5R EF ER 3F 3R ) ) {
        my $oligo_file = $o->oligo_finder_output_dir->file( $oligo . '.yaml' );
        ok $o->oligo_finder_output_dir->contains( $oligo_file )
            , "oligo finder dir contains $oligo yaml file";
    }

    for my $region ( qw( five_prime exon three_prime ) ) {
        my $oligo_pair_file = $o->oligo_finder_output_dir->file( $region . '_oligo_pairs.yaml' );
        ok $o->oligo_finder_output_dir->contains( $oligo_pair_file )
            , "oligo finder dir contains oligo $region pair yaml file";
    }

}

sub parse_primer : Test(11) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{ $o->run_primer3 } 'setup some primers to test against';
    ok my $result = $o->get_primer3_result( 'five_prime' )
        , 'can grab primer3 result from five_primer region';
    ok my $forward_primer = $result->next_primer_pair->forward_primer, 'can grab forward primer';

    ok! exists $o->primer3_oligos->{'5F'}, 'no data for 5F oligo exists';

    ok my $forward_primer_id = $o->parse_primer( $forward_primer, 'five_prime', 'forward' )
        ,'can call parse_primer';
    is $forward_primer_id, '5F-0', 'correct primer id';

    ok my $oligo_data = $o->primer3_oligos->{ '5F' }[0], 'have stored data hash for 5F oligo';
    is $oligo_data->{rank}, 0, 'rank is correct';
    is $oligo_data->{gc_content}, $forward_primer->gc_content, 'gc_content is correct';
    is $oligo_data->{oligo}, '5F', 'oligo_type is correct';
}

sub calculate_oligo_coords_and_sequence : Test(19) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{ $o->run_primer3 } 'setup some primers to test against';
    ok my $result = $o->get_primer3_result( 'five_prime' )
        , 'can grab primer3 result from five_primer region';
    ok my $forward_primer = $result->next_primer_pair->forward_primer, 'can grab forward primer';

    my %oligo_data;
    lives_ok{
        $o->calculate_oligo_coords_and_sequence( $forward_primer, 'five_prime', \%oligo_data, 'forward' )
    } 'can call calculate_oligo_coords_and_sequence';

    is $oligo_data{target_region_start}, $o->oligo_region_data->{five_prime}{start}
        , 'target_region_start is correct';
    is $oligo_data{oligo_start}, '32904836', 'oligo_start is correct';
    is $oligo_data{oligo_end}, '32904860', 'oligo_end is correct';
    is $oligo_data{offset}, '328', 'offset is correct';
    is $oligo_data{oligo_seq}, $forward_primer->seq->seq, 'oligo_seq is correct';

    my %new_oligo_data;
    lives_ok{
        $o->calculate_oligo_coords_and_sequence( $forward_primer, 'five_prime', \%new_oligo_data, 'reverse' )
    } 'can call calculate_oligo_coords_and_sequence with wrong direction';
    is $new_oligo_data{oligo_seq}, $forward_primer->seq->revcom->seq, 'oligo_seq is correct';

    ok $o->set_param( 'chr_strand', 1 ), 'can force strand of design to 1';
    lives_ok{
        $o->calculate_oligo_coords_and_sequence( $forward_primer, 'five_prime', \%new_oligo_data, 'forward' )
    } 'can call calculate_oligo_coords_and_sequence again, this time strand is +ve ';

    is $new_oligo_data{target_region_start}, $oligo_data{target_region_start},
        , 'target_region_start is the same on forward strand';
    is $new_oligo_data{oligo_start}, '32904836', 'oligo_start is correct';
    is $new_oligo_data{oligo_end}, '32904860', 'oligo_end is correct';
    is $new_oligo_data{offset}, $forward_primer->start, 'offset is correct';
    is $new_oligo_data{oligo_seq}, $forward_primer->seq->seq, 'oligo_seq is correct';
}

sub parse_primer3_results : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->run_primer3
    } 'setup test object';

    lives_ok{
        $o->parse_primer3_results
    } 'can call parse_primer3_results';

    for my $region ( qw( exon five_prime three_prime ) ) {
        ok exists $o->oligo_pairs->{ $region }, "We have primers for $region region";
    }
}

sub primer3_config_defaults : Tests(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok $o->has_primer3_default('primer_max_gc'), 'we have default primer3 config for max gc';
    is $o->get_primer3_default('primer_max_gc'), 60, 'value is correct, 60%';

    ok delete $o->default_primer3_config->{primer_max_gc}, 'can delete max gc value';

    throws_ok {
        $o->primer_max_gc
    } qr/No Primer3 config for primer_max_gc set/, 'throws error if no default set';
}

sub _get_test_object {
    my ( $test, $fail_data ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir;
    if ( $fail_data ) {
        $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/find_gibson_oligos_data_fail');
    }
    else {
        $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/find_gibson_oligos_data');
    }

    # need oligo target region files to test against, in oligo_target_regions dir
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir               => $dir,
        repeat_mask_class => [ 'trf', 'dust' ],
    );
}

1;

__END__
