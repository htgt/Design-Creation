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

sub region_length : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $metaclass = $test->get_test_object_metaclass();

    is $o->region_length_ER_3F, 200, 'default ER_3F region length correct';
    is $o->region_length_ER, 100, 'correctly calculated ER region length';
    is $o->region_length_3F, 100, 'correctly calculated 3F region length';

    my $new_obj = $metaclass->new_object(
        dir                 => tempdir( TMPDIR    => 1, CLEANUP => 1 )->absolute,
        species             => 'Human',
        five_prime_exon     => 'ENSE00002184393',
        target_genes        => [ 'test_gene' ],
        region_length_ER_3F => 201,
    );

    is $new_obj->region_length_ER, 100, 'correctly calculated ER region length given odd number';
    is $new_obj->region_length_3F, 100, 'correctly calculated 3F region length given odd number';
}

sub exon_region_start_and_end : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

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
    lives_ok {
        $new_obj->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

    is $new_obj->exon_region_start, $o->target_start - 300
        , 'exon_region_start value correct +ve strand';
    is $new_obj->exon_region_end, $o->target_end + 200
        , 'exon_region_end value correct +ve strand';
}

sub five_prime_region_start_and_end : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok {
        $o->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

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
    lives_ok {
        $new_obj->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

    is $new_obj->five_prime_region_start, $o->target_start - ( 300 + 1600 )
        , 'five_prime_region_start value correct +ve strand';
    is $new_obj->five_prime_region_end, $o->target_start - 301
        , 'five_prime_region_end value correct +ve strand';
}

sub three_prime_region_start_and_end : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    lives_ok {
        $o->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

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
    lives_ok {
        $new_obj->calculate_target_region_coordinates
    } 'can call calculate_target_region_coordinates';

    is $new_obj->three_prime_region_start, $o->target_end + 201
        , 'three_prime_region_start value correct +ve strand';
    is $new_obj->three_prime_region_end, $o->target_end + 200 + 1600
        , 'three_prime_region_end value correct +ve strand';
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
