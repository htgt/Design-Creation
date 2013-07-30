package Test::DesignCreate::CmdRole::FilterGibsonOligos;

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
# DesignCreate::Action::FilterGibsonOligos ( through command line )
# DesignCreate::CmdRole::FilterGibsonOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FilterGibsonOligos' );
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
    my $oligo_data = $oligos_data->[0];

    ok $o->validate_oligo( $oligo_data, '5R' ), 'validate_oligo check passes';
    ok !$o->validate_oligo( $oligo_data, 'U3' ), 'validate_oligo check fails, wrong oligo type';
    $oligo_data->{oligo_seq} = 'AAAATTTT';
    ok !$o->validate_oligo( $oligo_data, '5R' ), 'validate_oligo check fails';
}

sub validate_oligos_of_type : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligo_file = $o->oligo_finder_output_dir->file( '5F.yaml' ), 'can get 5F.yaml oligo file';
    ok $o->validate_oligos_of_type( $oligo_file, '5F' ), 'validate_oligo check passes';

    my $empty_file = $o->oligo_finder_output_dir->file( 'test.yaml' );
    $empty_file->touch;
    ok !$o->validate_oligos_of_type( $empty_file, '5F' ), 'validate_oligo check fails, empty oligo file';
}

sub validate_oligos : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok $o->validate_oligos(), 'validate_oligos check passes';

    ok $o->oligo_finder_output_dir->file( '5F.yaml' )->remove, 'can remove 5F.yaml file';

    throws_ok{
        $o->validate_oligos()
    } qr/Cannot find file/, 'throws error when no 5F.yaml file';

    $o->oligo_finder_output_dir->file( '5F.yaml' )->touch;

    throws_ok{
        $o->validate_oligos()
    } qr/No valid 5F oligos/, 'throws error when empty 5F.yaml file';

}

sub have_required_validated_oligos : Test(5){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok{
        $o->validate_oligos;
    } 'setup test object';

    ok $o->have_required_validated_oligos, 'have_required_validated_oligos returns true';

    ok delete $o->validated_oligos->{ER}, 'delete ER validated oligos';
    throws_ok{
        $o->have_required_validated_oligos
    } qr/No valid ER oligos/, 'throws error when missing required valid oligos';
}

sub output_validated_oligos : Test(9){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
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

sub _get_test_object {
    my ( $test ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/filter_gibson_oligos_data_minus');

    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::Role::EnsEMBL' ] );
    return $metaclass->new_object( dir => $dir);
}

1;

__END__
