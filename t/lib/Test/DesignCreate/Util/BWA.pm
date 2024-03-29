package Test::DesignCreate::Util::BWA;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use FindBin;
use Path::Class qw( dir tempdir );
use base qw( Test::Class Class::Data::Inheritable );

use DesignCreate::Util::BWA;

# Testing
# DesignCreate::Util::BWA

BEGIN {
    __PACKAGE__->mk_classdata( 'class' => 'DesignCreate::Util::BWA' );
}

# NOTE not testing the three_prime_check code, its not being used yet

sub constructor : Test(startup => 6) {
    my $test = shift;

    $ENV{'LIMS2_BWA_OLIGO_DIR'} = '/home/ubuntu/bwa_dump';

    my $primer_data = {
        '5F-1' => { 'seq' => 'GACCTTAAGATGTTATTTGGGCCAG' },
        '5F-0' => { 'seq' => 'aaaaaGACGTTATTTGGTCCTGGTC' },
        '5F-3' => { 'seq' => 'CTCCACCTGGTATTTGTGATCTTTG' },
        '5F-2' => { 'seq' => 'TAACAATACAAAAACTAGCCAGGCG' },
        '3F-0' => { 'seq' => 'CAAGTGGTTCAAGTATTCTCCTTAC' },
        '3F-1' => { 'seq' => 'TCCCCATAGGAATAAGCCAAAA' },
        '5R-3' => { 'seq' => 'CAGAGGTACAGATACAAGAAAAGTC' },
        '5R-1' => { 'seq' => 'ACGAATGTGTAAGTATGTGTGCATG' },
        '5R-0' => { 'seq' => 'GCATGCAATTCAGAGGTACAGATAC' },
        '5R-2' => { 'seq' => 'AAGTATGTGTGCATGCAATTCAGAG' },
        '3R-1' => { 'seq' => 'CTGCACAAGTTACTTAAATCAGCCA' },
        '3R-0' => { 'seq' => 'TTCTCTCATCTGTGAAAATGGGGAT' },
    };

    ok my $o = $test->class->new(
        primers         => $primer_data,
        species         => 'Human',
        num_bwa_threads => 1,
    ), 'we got a object';

    isa_ok $o, $test->class;

    note( 'Running bwa commands, may take a while...' );
    lives_ok{
        $o->generate_sam_file
    } 'can run bwa and generate sam file';

    my $alt_primer_data = {
        'left' => {
            'left_0' => { 'seq' => 'CAAGTGGTTCAAGTATTCTCCTTAC' },
            'left_1' => { 'seq' => 'TCCCCATAGGAATAAGCCAAAA' },
        },
        'right' => {
            'right_0' => { 'seq' => 'TTCTCTCATCTGTGAAAATGGGGAT' },
            'right_1' => { 'seq' => 'CTGCACAAGTTACTTAAATCAGCCA' },
        }
    };

    ok my $o_alt = $test->class->new(
        primers         => $alt_primer_data,
        species         => 'Human',
        num_bwa_threads => 1,
        design_id       => 123,
        well_id         => 'Test_Miseq_Crispr_456_18-11-2021',
    ), 'we got another object';

    isa_ok $o_alt, $test->class;

    note( 'Running more bwa commands...' );
    lives_ok{
        $o_alt->generate_sam_file
    } 'can run bwa and generate sam file';

    $test->{o} = $o;
    $test->{alt} = $o_alt;
}

sub _segment_unmapped : Tests(6) {
    my $test = shift;
    my $o = $test->{o}; 

    for my $flag ( qw( 4 5 ) ) {
        ok $o->_segment_unmapped( $flag ), "sam flag of $flag returns segment_unmapped true";
    }

    for my $flag ( qw( 0 1 256 272 ) ) {
        ok !$o->_segment_unmapped( $flag ), "sam flag of $flag returns segment_unmapped false";
    }
}

sub _primary_alignment : Tests(4) {
    my $test = shift;
    my $o = $test->{o}; 

    for my $flag ( qw( 0 16 ) ) {
        ok $o->_primary_alignment( $flag ), "sam flag of $flag returns primary_alignment true";
    }

    for my $flag ( qw( 256 272 ) ) {
        ok !$o->_primary_alignment( $flag ), "sam flag of $flag returns primary_alignment false";
    }
}

sub oligo_hits : Tests(5) {
    my $test = shift;
    my $o = $test->{o}; 

    ok my $oligo_hits = $o->oligo_hits, 'can call oligo_hits method';
    ok exists $oligo_hits->{'3F-1'}, 'we have data on 3F-1 oligo';
    is $oligo_hits->{'3F-1'}{hits}, 3, 'correct number of hits for 3F-1 oligo';
    ok exists $oligo_hits->{'3R-1'}, 'we have data on 3F-1 oligo';
    is $oligo_hits->{'3R-1'}{hits}, 1, 'correct number of hits for 3R-1 oligo';
}

sub _build_api : Tests(1) {
    my $test = shift;
    my $o = $test->{o};

    isa_ok $o->_build_api, 'WebAppCommon::Util::RemoteFileAccess', '_build_api returns RemoteFileAccess object';
}

sub _build_query_file : Tests(6) {
    my $test = shift;
    my $o = $test->{o};
    my $o_alt = $test->{alt};

    my $query_file = $o->_build_query_file;
    like $query_file,
    qr/^\/home\/ubuntu\/bwa_dump\/_[\w-]+\/_oligos\.fasta/,
    '_build_query_file outputs query file path as expected';
    ok $o->api->check_file_existence($query_file), 'query file exists';
    my $expected_file_content =
        ">3F-0\nCAAGTGGTTCAAGTATTCTCCTTAC\n" .
        ">3F-1\nTCCCCATAGGAATAAGCCAAAA\n" .
        ">3R-0\nTTCTCTCATCTGTGAAAATGGGGAT\n" .
        ">3R-1\nCTGCACAAGTTACTTAAATCAGCCA\n" .
        ">5F-0\naaaaaGACGTTATTTGGTCCTGGTC\n" .
        ">5F-1\nGACCTTAAGATGTTATTTGGGCCAG\n" .
        ">5F-2\nTAACAATACAAAAACTAGCCAGGCG\n" .
        ">5F-3\nCTCCACCTGGTATTTGTGATCTTTG\n" .
        ">5R-0\nGCATGCAATTCAGAGGTACAGATAC\n" .
        ">5R-1\nACGAATGTGTAAGTATGTGTGCATG\n" .
        ">5R-2\nAAGTATGTGTGCATGCAATTCAGAG\n" .
        ">5R-3\nCAGAGGTACAGATACAAGAAAAGTC\n";
    is $o->api->get_file_content($query_file), $expected_file_content, 'query file contains expected content';


    $query_file = $o_alt->_build_query_file;
    like $query_file,
    qr/^\/home\/ubuntu\/bwa_dump\/Test_Miseq_Crispr_456_18-11-2021_[\w-]+\/123_oligos.fasta/,
    '_build_query_file outputs alt query file path as expected';
    ok $o_alt->api->check_file_existence($query_file), 'alt query file exists';
    $expected_file_content =
        ">left_0\nCAAGTGGTTCAAGTATTCTCCTTAC\n" .
        ">left_1\nTCCCCATAGGAATAAGCCAAAA\n" .
        ">right_0\nTTCTCTCATCTGTGAAAATGGGGAT\n" .
        ">right_1\nCTGCACAAGTTACTTAAATCAGCCA\n";
    is $o_alt->api->get_file_content($query_file), $expected_file_content, 'alt query file contains expected content';
}

1;

__END__
