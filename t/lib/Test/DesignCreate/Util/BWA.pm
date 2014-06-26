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

sub constructor : Test(startup => 3) {
    my $test = shift;

    ok my $o = $test->class->new(
        query_file      => _get_test_data_file( 'bwa_query.fasta' ), 
        work_dir        => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        num_bwa_threads => 1,
    ), 'we got a object';

    isa_ok $o, $test->class;

    note( 'Running bwa commands, may take a while...' );
    lives_ok{
        $o->generate_sam_file
    } 'can run bwa and generate sam file';

    $test->{o} = $o;
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

sub _get_test_data_file {
    my ( $filename ) = @_;
    my $data_dir = dir($FindBin::Bin)->subdir('test_data/bwa_data/');
    my $file = $data_dir->file($filename);

    return $file->stringify;
}

1;

__END__
