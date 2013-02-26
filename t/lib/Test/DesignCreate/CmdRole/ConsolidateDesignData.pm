package Test::DesignCreate::CmdRole::ConsolidateDesignData;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::ConsolidateDesignData;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::ConsolidateDesignData ( through command line )
# DesignCreate::CmdRole::ConsolidateDesignData, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::ConsolidateDesignData' );
}

sub valid_consolidate_design_data_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'consolidate-design-data',
        '--dir', $o->dir->stringify,
        '--target-gene', 'LBL-TEST',
        '--strand', 1,
        '--chromosome', 11,

    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no stdedd';
    ok !$result->error, 'no command errors';
}

sub build_oligo_array : Test(no_plan) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_oligo_array
    } 'can call build_oligo_array';

    ok $o->picked_oligos, 'have array of picked oligos';

    ok $o->validated_oligo_dir->file( 'G5.yaml' )->remove, 'can remove G5 oligo file';
    throws_ok{
        $o->build_oligo_array
    } qr/Cannot find file/ , 'throws error on missing oligo file';

}

sub get_oligo : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $oligos = LoadFile( $u5_file );
    my @all_u5_oligos = @{ $oligos };

    ok my $oligo_data = $o->get_oligo( $oligos, 'U5' ), 'can call get_oligo';

    is $oligo_data->{seq}, $all_u5_oligos[0]{oligo_seq}
        , 'have expected U5 oligo seq, first in list';

    ok my $g5_file = $o->validated_oligo_dir->file( 'G5.yaml' ), 'can find G5 oligo file';
    my $g5_oligos = LoadFile( $g5_file );
    ok my $g5_oligo_data = $o->get_oligo( $g5_oligos, 'G5' ), 'can call get_oligo';
    my ( $expected_g5_oligo ) = grep{ $_->{id} eq $o->gap_oligo_pair->{G5} } @{ $g5_oligos };

    is $g5_oligo_data->{seq}, $expected_g5_oligo->{oligo_seq}, 'get expected G5 oligo';

    throws_ok{
        $o->get_oligo( $g5_oligos, 'G3' )
    } qr/Can not find G3 oligo/,
        'throws errors if we can not find oligo';
}

sub _build_gap_oligo_pair : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my $gap_oligo_file = $o->validated_oligo_dir->file( 'gap_oligo_pairs.yaml' );
    ok $gap_oligo_file->remove, 'can remove gap oligo pair file';
    throws_ok{
        $o->gap_oligo_pair
    } qr/Cannot find file/
        , 'throws errors if we do not have gap oligo data file';

    ok $gap_oligo_file->touch, 'can create blank gap oligo file';
    throws_ok{
        $o->gap_oligo_pair
    } qr/No gap oligo data/
        , 'throws errors if no data in gap oligo file';
}

sub format_oligo_data : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $oligos = LoadFile( $u5_file );
    my $test_oligo = shift @{ $oligos };

    ok my $oligo_data = $o->format_oligo_data( $test_oligo ), 'can call format_oligo_data';

    is $oligo_data->{type}, $test_oligo->{oligo}, 'correct oligo type';
    is $oligo_data->{seq}, $test_oligo->{oligo_seq}, 'correct oligo seq';
    my $loci = shift @{ $oligo_data->{loci} };
    is $loci->{chr_name}, 11, 'correct chromosome';
    is $loci->{chr_start}, $test_oligo->{oligo_start}, 'correct start coordinate';
}

sub create_design_file : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->get_design_phase;
        $o->build_oligo_array;
    } 'test object setup ok';

    lives_ok{
        $o->create_design_file
    } 'can call create_design_file';

    my $design_data_file = $o->dir->file( 'design_data.yaml' );
    ok $o->dir->contains( $design_data_file ), 'design data file created';

    my $design_data = LoadFile( $design_data_file );

    is $design_data->{type}, 'deletion', 'correct design type';
    is $design_data->{species}, 'Mouse', 'correct species';
    is_deeply $design_data->{gene_ids}, [ 'LBL-1' ], 'correct gene ids';
    is $design_data->{created_by}, 'test', 'correct created_by';
}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/consolidate_design_data');

    dircopy( $data_dir->stringify, $dir->stringify . '/validated_oligos' );

    return $test->test_class->new(
        dir          => $dir,
        target_genes => [ 'LBL-1' ],
        chr_name     => 11,
        chr_strand   => 1,
        created_by   => 'test',
    );
}

1;

__END__
