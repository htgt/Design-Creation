package Test::DesignCreate::CmdRole::ConsolidateDesignData;

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
# DesignCreate::Action::ConsolidateDesignData ( through command line )
# DesignCreate::CmdRole::ConsolidateDesignData

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::ConsolidateDesignData' );
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
        '--design-method', 'deletion',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no stdedd';
    ok !$result->error, 'no command errors';
}

sub build_oligo_array : Test(18) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_oligo_array
    } 'can call build_oligo_array';

    ok my $picked_oligos = $o->picked_oligos, 'have array of picked oligos';

    for my $oligo_type ( qw( G5 U5 D3 G3 ) ) {
        my ( $oligo ) = grep { $_->{type} eq $oligo_type } @{ $picked_oligos };
        ok $oligo, "have $oligo_type oligo";
    }

    ok $o->validated_oligo_dir->file( 'G5.yaml' )->remove, 'can remove G5 oligo file';
    throws_ok{
        $o->build_oligo_array
    } qr/Cannot find file/ , 'throws error on missing oligo file';

    ok my $c_o = $test->_get_test_object( { design_method => 'conditional' } ), 'can grab test object';
    lives_ok{
        $c_o->build_oligo_array
    } 'can call build_oligo_array';

    ok my $cond_picked_oligos = $c_o->picked_oligos, 'have array of conditional picked oligos';
    for my $oligo_type ( qw( G5 U5 U3 D5 D3 G3 ) ) {
        my ( $oligo ) = grep { $_->{type} eq $oligo_type } @{ $cond_picked_oligos };
        ok $oligo, "have $oligo_type oligo";
    }
}

sub get_oligo : Test(11) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $u5_oligos = LoadFile( $u5_file );
    my @all_u5_oligos = @{ $u5_oligos };

    ok my $oligo_data = $o->get_oligo( $u5_oligos, 'U5' ), 'can call get_oligo';

    is $oligo_data->{seq}, $all_u5_oligos[0]{oligo_seq}
        , 'have expected U5 oligo seq, first in list';

    ok my $g5_file = $o->validated_oligo_dir->file( 'G5.yaml' ), 'can find G5 oligo file';
    my $g5_oligos = LoadFile( $g5_file );
    ok my $g5_oligo_data = $o->get_oligo( $g5_oligos, 'G5' ), 'can call get_oligo';
    my ( $expected_g5_oligo ) = grep{ $_->{id} eq $o->G_oligo_pair->{G5} } @{ $g5_oligos };

    is $g5_oligo_data->{seq}, $expected_g5_oligo->{oligo_seq}, 'get expected G5 oligo';

    throws_ok{
        $o->get_oligo( [], 'U3' )
    } qr/Can not find U3 oligo/,
        'throws errors if we can not find oligo';

    #conditional design, U / D oligos from best pair, not just best individual oligo
    ok my $c_o = $test->_get_test_object( { design_method => 'conditional' } ), 'can grab test object';
    ok my $u5_oligo_data = $c_o->get_oligo( $u5_oligos, 'U5' ), 'can call get_oligo';
    my ( $expected_u5_oligo ) = grep{ $_->{id} eq $o->U_oligo_pair->{U5} } @{ $u5_oligos };

    is $u5_oligo_data->{seq}, $expected_u5_oligo->{oligo_seq}, 'get expected U5 oligo for condition design';

}

sub get_oligo_pair : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligos = $o->get_oligo_pair( 'G' ), 'can call get_oligo_pair';

    my $gap_oligo_file = $o->validated_oligo_dir->file( 'G_oligo_pairs.yaml' );
    ok $gap_oligo_file->remove, 'can remove gap oligo pair file';
    throws_ok{
        $o->get_oligo_pair( 'G' )
    } qr/Cannot find file/
        , 'throws errors if we do not have gap oligo data file';

    ok $gap_oligo_file->touch, 'can create blank gap oligo file';
    throws_ok{
        $o->get_oligo_pair( 'G' )
    } qr/No oligo data/
        , 'throws errors if no data in gap oligo file';
}

sub pick_oligo_from_pair : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $u5_oligos = LoadFile( $u5_file );
    ok my $oligo = $o->pick_oligo_from_pair( $u5_oligos, 'U5' );
    is $oligo->{id}, 'U5-11', 'picked right U5 oligo';

    ok my $u3_file = $o->validated_oligo_dir->file( 'U3.yaml' ), 'can find U3 oligo file';
    my $u3_oligos = LoadFile( $u3_file );
    ok $oligo = $o->pick_oligo_from_pair( $u3_oligos, 'U3' );
    is $oligo->{id}, 'U3-10', 'picked right U3 oligo';

    throws_ok{
        $o->pick_oligo_from_pair( $u3_oligos, 'U5' )
    } qr/Unable to find U5 oligo:/
        ,'throws error when we can not find specified oligo';

    throws_ok{
        $o->pick_oligo_from_pair( $u3_oligos, 'X5' )
    } qr/Attribute X_oligo_pair does not exist/
        ,'throws error with invalid oligo type';
}

sub format_oligo_data : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $oligos = LoadFile( $u5_file );
    my $test_oligo = shift @{ $oligos };
    ok $test_oligo->{oligo_seq} = lc( $test_oligo->{oligo_seq} ), 'can lowercase oligo seq';

    ok my $oligo_data = $o->format_oligo_data( $test_oligo ), 'can call format_oligo_data';

    is $oligo_data->{type}, $test_oligo->{oligo}, 'correct oligo type';
    isnt $oligo_data->{seq}, $test_oligo->{oligo_seq}, 'oligo sequences different case';
    is $oligo_data->{seq}, uc( $test_oligo->{oligo_seq} ), 'same oligo seq once uppercase original data';
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
    my ( $test, $params ) = @_;
    my $design_method = $params->{design_method} || 'deletion';

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/consolidate_design_data');

    dircopy( $data_dir->stringify, $dir->stringify . '/validated_oligos' );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir           => $dir,
        target_genes  => [ 'LBL-1' ],
        chr_name      => 11,
        chr_strand    => 1,
        created_by    => 'test',
        design_method => $design_method,
    );
}

1;

__END__
