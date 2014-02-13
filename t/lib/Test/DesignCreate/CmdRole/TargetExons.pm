package Test::DesignCreate::CmdRole::TargetExons;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::TargetExons
# DesignCreate::Action::TargetExons ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::TargetExons' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 );

    #note: small chance with new ensembl build that we will need
    #      to update the exon id
    my @argv_contents = (
        'target-exons',
        '--dir'           ,$dir->stringify,
        '--target-gene'   ,'test_gene',
        '--species'       ,'Human',
        '--target-exon'   ,'ENSE00002184393'
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub calculate_target_region_coordinates : Tests(17) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();

    note( 'Single exon targets' );
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok my $exon = $o->build_exon( $o->five_prime_exon ), 'can grab exon';

    lives_ok {
        $o->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';
    is $o->target_start, $exon->seq_region_start, 'target start is correct';
    is $o->target_end, $exon->seq_region_end, 'target end is correct';

    note( 'Multi exon targets, -ve strand' );
    ok my $cbx1_obj = $metaclass->new_object(
        dir              => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species          => 'Human',
        five_prime_exon  => 'ENSE00001515177',
        three_prime_exon => 'ENSE00002771605',
        target_genes     => [ 'cbx1' ],
    ), 'can grab new object with multi exon targets on -ve strand';
    ok my $exon_5p = $o->build_exon( $cbx1_obj->five_prime_exon ), 'can grab 5 prime exon';
    ok my $exon_3p = $o->build_exon( $cbx1_obj->three_prime_exon ), 'can grab 3 prime exon';
    lives_ok {
        $cbx1_obj->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';
    is $cbx1_obj->target_start, $exon_3p->seq_region_start, 'target start is correct';
    is $cbx1_obj->target_end, $exon_5p->seq_region_end, 'target end is correct';

    note( 'Multi exon targets, +ve strand' );
    ok my $brac2_obj = $metaclass->new_object(
        dir              => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species          => 'Human',
        five_prime_exon  => 'ENSE00001484009',
        three_prime_exon => 'ENSE00003659301 ',
        target_genes     => [ 'brac2' ],
    ), 'can grab new object with multi exon targets';
    ok $exon_5p = $o->build_exon( $brac2_obj->five_prime_exon ), 'can grab 5 prime exon';
    ok $exon_3p = $o->build_exon( $brac2_obj->three_prime_exon ), 'can grab 3 prime exon';
    lives_ok {
        $brac2_obj->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';
    is $brac2_obj->target_start, $exon_5p->seq_region_start, 'target start is correct';
    is $brac2_obj->target_end, $exon_3p->seq_region_end, 'target end is correct';
}

sub create_target_coordinate_file : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->target_coordinates
    } 'can get_oligo_pair_region_coordinates';

    my $target_file = $o->oligo_target_regions_dir->file( 'target_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $target_file )
        , "$target_file file exists";
}

sub validate_exon_targets : Tests(13) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass( [ 'DesignCreate::CmdRole::OligoPairRegionsGibson' ] );
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $h2afx_exon = $o->build_exon( 'ENSE00002184393' ), 'can grab exon';
    ok my $cbx1_exon_5p = $o->build_exon( 'ENSE00001515177' ), 'can grab exon';
    ok my $cbx1_exon_3p = $o->build_exon( 'ENSE00002771605' ), 'can grab exon';

    throws_ok{
        $o->validate_exon_targets( $h2afx_exon, $cbx1_exon_5p )
    } qr/Exon mismatch/, 'throws error if exons belong to different genes';

    # -ve strand exons
    # validate_exon_targets is called in BUILD method
    ok my $cbx1_obj = $metaclass->new_object(
        dir              => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species          => 'Human',
        five_prime_exon  => 'ENSE00001515177',
        three_prime_exon => 'ENSE00002771605',
        target_genes     => [ 'cbx1' ],
    ), 'can grab new object with multi exon targets on -ve strand';
    ok $cbx1_obj->chr_strand(-1), 'set strand as -1';

    throws_ok{
        $cbx1_obj->validate_exon_targets( $cbx1_exon_3p, $cbx1_exon_5p )
    } qr/On -ve strand, five prime exon/, 'error if exons are in wrong order on -ve strand';

    # brac2 exons on +ve strand
    # validate_exon_targets is called in BUILD method
    ok my $brac2_obj = $metaclass->new_object(
        dir              => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species          => 'Human',
        five_prime_exon  => 'ENSE00001484009',
        three_prime_exon => 'ENSE00003659301 ',
        target_genes     => [ 'brac2' ],
    ), 'can grab new object with multi exon targets';
    ok my $brac2_exon_5p = $o->build_exon( 'ENSE00001484009' ), 'can grab exon';
    ok my $brac2_exon_3p = $o->build_exon( 'ENSE00003659301 ' ), 'can grab exon';

    ok $brac2_obj->chr_strand(1), 'set strand as 1';
    throws_ok{
        $brac2_obj->validate_exon_targets( $brac2_exon_3p, $brac2_exon_5p )
    } qr/On \+ve strand, five prime exon/, 'error if exons are in wrong order on +ve strand';

}

sub build_exon : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    throws_ok {
        $o->build_exon( 'ENSE00002184' );
    } qr/Unable to retrieve exon/, 'throws error for invalid exon id';

    ok my $exon = $o->build_exon( 'ENSE00002184393' ), 'can retrieve exon';
    isa_ok $exon, 'Bio::EnsEMBL::Exon';
    is $exon->coord_system_name, 'chromosome', 'coordinate system name for exon is chromosome';
}

sub _get_test_object {
    my $test = shift;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
    );
}


1;

__END__
