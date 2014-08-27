package Test::DesignCreate::CmdRole::ConsolidateDesignData;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::Cmd::Step::ConsolidateDesignData ( through command line )
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

sub oligo_classes : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    is_deeply $o->oligo_classes, [ 'G' ], 'oligo classes for deletion design correct';

    ok $o->clear_oligo_classes, 'can clear oligo_classes attribute value';
    ok $o->set_param( 'design_method' => 'gibson' ), 'can set design_method to gibson';
    is_deeply $o->oligo_classes, [ qw( exon five_prime three_prime ) ]
        , 'oligo classes for gibson design correct';

    ok $o->clear_oligo_classes, 'can clear oligo_classes attribute value';
    ok $o->set_param( 'design_method' => 'conditional' ), 'can set design_method to conditional';
    is_deeply $o->oligo_classes, [ qw( G U D ) ]
        , 'oligo classes for conditional design correct';
}

sub all_oligo_pairs : Test(12) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $g_oligo_pair_file = $o->validated_oligo_dir->file( 'G_oligo_pairs.yaml' )
        , 'can grab g oligo pairs file object';
    ok $g_oligo_pair_file->remove, 'can remove G oligo pair file';
    throws_ok{
        $o->all_oligo_pairs
    } qr/Cannot find file/ , 'throws error on missing oligo file';

    ok $g_oligo_pair_file->touch, 'create empty G oligo pair file';
    throws_ok{
        $o->all_oligo_pairs
    } qr/No oligo data in/ , 'throws error on empty oligo file';

    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';

    ok my $oligo_pairs = $c_o->all_oligo_pairs, 'can build all_oligo_pairs';

    for my $oligo_class ( qw( G U D ) ) {
        ok exists $oligo_pairs->{$oligo_class}, "$oligo_class oligo pair data exists";
    }
}

sub all_valid_oligos : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $g5_oligo_file = $o->validated_oligo_dir->file( 'G5.yaml' ), 'can grab g5 oligo file object';
    ok $g5_oligo_file->remove, 'can remove G5 oligo file';
    throws_ok{
        $o->all_valid_oligos
    } qr/Cannot find file/ , 'throws error on missing oligo file';

    ok $g5_oligo_file->touch, 'create empty G5 oligo file';
    throws_ok{
        $o->all_valid_oligos
    } qr/No oligo data in/ , 'throws error on empty oligo file';

    ok $o = $test->_get_test_object, 'can grab another test object';

    lives_ok{
        $o->all_valid_oligos
    } 'can build all_valid_oligos';
}

sub consolidate_design_data : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->consolidate_design_data
    } 'can call consolidate_design_data';

    my $design_data_file = $o->dir->file( 'design_data.yaml' );
    ok $o->dir->contains( $design_data_file ), 'design data file created';

    my $alt_design_data_file = $o->dir->file( 'alt_designs.yaml' );
    ok $o->dir->contains( $alt_design_data_file ), 'alternative design data file created';
}

sub build_primary_design_oligos : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_primary_design_oligos
    } 'can call build_primary_design_oligos';

    ok $o->primary_design_oligos, 'have primary design oligo data';
}

sub build_alternate_design_oligos : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok $o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';

    lives_ok{
        $o->build_alternate_design_oligos
    } 'can call build_alternate_design_oligos';

    ok my $num_alt_designs = @{ $o->alternate_designs_oligos }, 'can grab number of alternate designs';
    is $num_alt_designs, 3, 'expected number of alternate designs';
}

sub build_design_oligo_data : Test(16) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $oligo_data = $o->build_design_oligo_data( 0 ), 'can call build_design_oligo_data';

    for my $oligo_type ( qw( G5 U5 D3 G3 ) ) {
        my ( $oligo ) = grep { $_->{type} eq $oligo_type } @{ $oligo_data };
        ok $oligo, "have $oligo_type oligo";
    }

    ok !$o->build_design_oligo_data( 5 ), 'no data returned for non existant alternate design number';

    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';
    ok my $cond_oligo_data = $c_o->build_design_oligo_data( 1 ), 'can call build_design_oligo_data';

    for my $oligo_type ( qw( G5 U5 U3 D5 D3 G3 ) ) {
        my ( $oligo ) = grep { $_->{type} eq $oligo_type } @{ $cond_oligo_data };
        ok $oligo, "have $oligo_type oligo";
    }
}

sub get_oligo : Tests(15) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $u5_oligos = LoadFile( $u5_file );
    my @all_u5_oligos = @{ $u5_oligos };
    ok my $oligo_data = $o->get_oligo( 'U5', 0 ), 'can call get_oligo';
    is $oligo_data->{seq}, $all_u5_oligos[0]{oligo_seq}
        , 'have expected U5 oligo seq, first in list';

    ok my $g5_file = $o->validated_oligo_dir->file( 'G5.yaml' ), 'can find G5 oligo file';
    my $g5_oligos = LoadFile( $g5_file );
    ok my $g5_oligo_data = $o->get_oligo( 'G5', 0 ), 'can call get_oligo';
    my ( $expected_g5_oligo ) = grep{ $_->{id} eq $o->all_oligo_pairs->{G}[0]{G5} } @{ $g5_oligos };
    is $g5_oligo_data->{seq}, $expected_g5_oligo->{oligo_seq}, 'get expected G5 oligo';

    $o->all_valid_oligos->{U3} = [];
    throws_ok{
        $o->get_oligo( 'U3', 0 )
    } qr/Can not find U3 oligo/,
        'throws errors if we can not find oligo';

    #conditional design, U / D oligos from best pair, not just best individual oligo
    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';
    ok my $u5_oligo_data = $c_o->get_oligo( 'U5', 0 ), 'can call get_oligo';
    my ( $expected_u5_oligo ) = grep{ $_->{id} eq $c_o->all_oligo_pairs->{U}[0]{U5} } @{ $u5_oligos };
    is $u5_oligo_data->{seq}, $expected_u5_oligo->{oligo_seq}, 'get expected U5 oligo for condition design';

    ok my $o2 = $test->_get_test_object( 'test_data/consolidate_design_data_comment' ), 'can grab test object';
    ok $oligo_data = $o2->get_oligo( '3F', 0 ), 'can call get_oligo';
    ok exists $oligo_data->{off_targets}, '.. returned oligo has off targets data';
}

sub pick_oligo_from_pair : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok $o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';

    ok my $u_pair_file = $o->validated_oligo_dir->file( 'U_oligo_pairs.yaml' ), 'can find U oligo pair file';
    my $u_oligos_pairs = LoadFile( $u_pair_file );
    ok my $u5_oligo = $o->pick_oligo_from_pair( 'U5', 0 );
    is $u5_oligo->{id}, $u_oligos_pairs->[0]{U5}, 'picked right U5 oligo';

    ok my $u3_oligo = $o->pick_oligo_from_pair( 'U3', 0 );
    is $u3_oligo->{id}, $u_oligos_pairs->[0]{U3}, 'picked right U3 oligo';

    throws_ok{
        $o->pick_oligo_from_pair( 'X5', 0 )
    } qr/Can not find information on X oligo pairs/
        ,'throws error when we can not find specified oligo';

    throws_ok{
        $o->pick_oligo_from_pair( 'U5', 4 )
    } qr/Unable to find U5 oligo: U5-99/
        ,'throws error with non-existant oligo';

    ok !$o->pick_oligo_from_pair( 'U5', 5 ), 'no fifth pair, return undef';
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

sub create_primary_design_file : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_primary_design_oligos;
    } 'test object setup ok';

    lives_ok{
        $o->create_primary_design_file
    } 'can call create_design_file';

    my $design_data_file = $o->dir->file( 'design_data.yaml' );
    ok $o->dir->contains( $design_data_file ), 'design data file created';

    my $design_data = LoadFile( $design_data_file );
    is $design_data->{type}, 'deletion', 'correct design type';
    is_deeply $design_data->{gene_ids},
        [ { gene_id => 'LBL-1', gene_type_id => 'enhancer-region' } ], 'correct gene ids';

    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';

    lives_ok{
        $c_o->build_primary_design_oligos;
        $c_o->create_primary_design_file
    } 'can call create_design_file';

    my $cond_design_data_file = $c_o->dir->file( 'design_data.yaml' );
    ok $c_o->dir->contains( $cond_design_data_file ), 'design data file created';
}

sub create_alt_design_file : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_alternate_design_oligos;
    } 'test object setup ok';

    lives_ok{
        $o->create_alt_design_file
    } 'can call create_alt_design_file';

    my $alt_design_data_file = $o->dir->file( 'alt_designs.yaml' );
    ok $o->dir->contains( $alt_design_data_file ), 'alt design data file created';

    my $alt_design_data = LoadFile( $alt_design_data_file );

    my $num_alt_designs = @{ $alt_design_data };
    is $num_alt_designs, 2, 'correct number of alternative designs, deletion';

    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional';

    lives_ok{
        $c_o->build_alternate_design_oligos;
        $c_o->create_alt_design_file
    } 'can call create_alt_design_file';

    my $alt_cond_design_data_file = $c_o->dir->file( 'alt_designs.yaml' );
    ok $c_o->dir->contains( $alt_cond_design_data_file ), 'alt design data file created';

    my $alt_cond_design_data = LoadFile( $alt_cond_design_data_file );
    my $num_cond_alt_designs = @{ $alt_cond_design_data };
    is $num_cond_alt_designs, 3, 'correct number of alternative designs, conditional';
}

sub build_design_data : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_primary_design_oligos;
    } 'test object setup ok';

    ok my $design_data = $o->build_design_data( $o->primary_design_oligos ), 'can call build_design_data';

    is $design_data->{type}, 'deletion', 'correct design type';
    is $design_data->{species}, 'Mouse', 'correct species';
    is_deeply $design_data->{gene_ids},
        [ { gene_id => 'LBL-1', gene_type_id => 'enhancer-region' } ], 'correct gene ids';
    is $design_data->{created_by}, 'test', 'correct created_by';
    ok !exists $design_data->{phase}, 'phase value not set';
}

sub build_design_comment : Tests(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_primary_design_oligos;
    } 'test object setup ok';

    ok !$o->build_design_comment( $o->primary_design_oligos ),
        'calling build_design_comment with no off_targets data returns undef';

    ok my $o2 = $test->_get_test_object( 'test_data/consolidate_design_data_comment' ), 'can grab test object';

    lives_ok{
        $o2->build_primary_design_oligos;
    } 'test object setup ok';

    ok my $design_comment = $o2->build_design_comment( $o2->primary_design_oligos ),
        'calling build_design_comment with off_targets data returns a hash ref';

    is $design_comment->{category}, 'Oligo Off Target Hits', '.. and the category of the comment is correct';
}

sub oligo_off_target_data : Tests(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object('test_data/consolidate_design_data_comment'),
        'can grab test object';

    ok $o->oligo_off_target_data, 'we have off target data hash';
    ok $o->has_oligo_off_target_data('3R-0'), 'we have off target data for 3R-0 oligo';
    ok my $off_target_data = $o->get_oligo_off_target_data('3R-0'), '.. and we can grab the data';
    is $off_target_data->{hits}, 8, '.. and it has the correct number of hits';
}

sub _get_test_object {
    my ( $test, $data_dir_name ) = @_;
    $data_dir_name //= 'test_data/consolidate_design_data';

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir($data_dir_name);

    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir           => $dir,
        target_genes  => [ 'LBL-1' ],
        created_by    => 'test',
    );
}

1;

__END__
