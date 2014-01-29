package Test::DesignCreate::CmdRole::OligoPairRegionsGibson;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::OligoPairRegionsGibson
# DesignCreate::Action::OligoPairRegionsGibson ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::OligoPairRegionsGibson' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 );

    #note: small chance with new ensembl build that we will need
    #      to update the exon id
    my @argv_contents = (
        'oligo-pair-regions-gibson',
        '--dir'           ,$dir->stringify,
        '--target-gene'   ,'test_gene',
        '--species'       ,'Human',
        '--target-exon'   ,'ENSE00002184393'
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub build_exon : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $metaclass = $test->get_test_object_metaclass();

    throws_ok {
        $o->build_exon( 'ENSE00002184' );
    } qr/Unable to retrieve exon/, 'throws error for invalid exon id';

    ok my $exon = $o->build_exon( 'ENSE00002184393' ), 'can retrieve exon';
    isa_ok $exon, 'Bio::EnsEMBL::Exon';
    is $exon->coord_system_name, 'chromosome', 'coordinate system name for exon is chromosome';
}

sub region_length : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $metaclass = $test->get_test_object_metaclass();

    is $o->region_length_ER_3F, 200, 'default ER_3F region length correct';
    is $o->region_length_ER, 100, 'correctly calculated ER region length';
    is $o->region_length_3F, 100, 'correctly calculated 3F region length';

    my $new_obj = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
        region_length_ER_3F => 201,
    );

    is $new_obj->region_length_ER, 100, 'correctly calculated ER region length given odd number';
    is $new_obj->region_length_3F, 100, 'correctly calculated 3F region length given odd number';
}

sub target_start_and_end : Tests(14) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();

    note( 'Single exon targets' );
    ok my $o = $test->_get_test_object, 'can grab test object';
    ok my $exon = $o->build_exon( $o->five_prime_exon ), 'can grab exon';

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
    is $brac2_obj->target_start, $exon_5p->seq_region_start, 'target start is correct';
    is $brac2_obj->target_end, $exon_3p->seq_region_end, 'target end is correct';
}

sub validate_exon_targets : Tests(11) {
    my $test = shift;
    my $metaclass = $test->get_test_object_metaclass();
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

    throws_ok{
        $brac2_obj->validate_exon_targets( $brac2_exon_3p, $brac2_exon_5p )
    } qr/On \+ve strand, five prime exon/, 'error if exons are in wrong order on +ve strand'; 

}

sub exon_region_start_and_end : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    is $o->chr_strand, -1, 'strand is -1';
    is $o->exon_region_start, $o->target_start - 200
        , 'exon_region_start value correct -ve strand';
    is $o->exon_region_end, $o->target_end + 300
        , 'exon_region_end value correct -ve strand';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
        chr_strand      => 1,
    );

    is $new_obj->chr_strand, 1, 'forced strand to be 1';
    is $new_obj->exon_region_start, $o->target_start - 300
        , 'exon_region_start value correct +ve strand';
    is $new_obj->exon_region_end, $o->target_end + 200
        , 'exon_region_end value correct +ve strand';
}

sub five_prime_region_start_and_end : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    is $o->chr_strand, -1, 'strand is -1';
    is $o->five_prime_region_start, $o->target_end + 301
        , 'five_prime_region_start value correct -ve strand';
    is $o->five_prime_region_end, $o->target_end + 300 + 1600
        , 'five_prime_region_end value correct -ve strand';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
        chr_strand      => 1,
    );

    is $new_obj->chr_strand, 1, 'forced strand to be 1';
    is $new_obj->five_prime_region_start, $o->target_start - ( 300 + 1600 )
        , 'five_prime_region_start value correct +ve strand';
    is $new_obj->five_prime_region_end, $o->target_start - 301
        , 'five_prime_region_end value correct +ve strand';
}

sub three_prime_region_start_and_end : Test(7) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    is $o->chr_strand, -1, 'strand is -1';
    is $o->three_prime_region_start, $o->target_start - ( 200 + 1600 )
        , 'three_prime_region_start value correct -ve strand';
    is $o->three_prime_region_end, $o->target_start - 201
        , 'three_prime_region_end value correct -ve strand';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
        chr_strand      => 1,
    );

    is $new_obj->chr_strand, 1, 'forced strand to be 1';
    is $new_obj->three_prime_region_start, $o->target_end + 201
        , 'three_prime_region_start value correct +ve strand';
    is $new_obj->three_prime_region_end, $o->target_end + 200 + 1600
        , 'three_prime_region_end value correct +ve strand';
}

sub check_oligo_region_sizes : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->check_oligo_region_sizes
    } 'checks pass for valid input';

    my $metaclass = $test->get_test_object_metaclass();
    my $new_obj2 = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        five_prime_exon => 'ENSE00002184393',
        target_genes    => [ 'test_gene' ],
        region_length_5F => 10,
    );

    throws_ok{
        $new_obj2->get_oligo_pair_region_coordinates
    } qr/5F region too small/
        , 'throws error if a oligo region is too small';
}

sub get_oligo_pair_region_coordinates : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->get_oligo_pair_region_coordinates
    } 'can get_oligo_pair_region_coordinates';

    ok exists $o->oligo_region_coordinates->{exon}{start}, 'we have a exon region start value';
    ok exists $o->oligo_region_coordinates->{exon}{end}, 'we have a exon region end value';

    my $oligo_region_file = $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $oligo_region_file )
        , "$oligo_region_file oligo file exists";

}

sub _get_test_object {
    my ( $test, $params ) = @_;

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
