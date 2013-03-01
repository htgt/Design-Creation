package Test::DesignCreate::Role::OligoTargetRegions;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::OligoTargetRegions;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Role::OligoTargetRegions

BEGIN {
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::OligoRegionsInsDel' );
}

sub get_oligo_region_offset : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $offset = $o->get_oligo_region_offset('G5'), 'can get_oligo_region_offset';
    is $offset, $o->G5_region_offset, 'is expected offset value';
    throws_ok { $o->get_oligo_region_offset('M3') }
        qr/Attribute M3_region_offset does not exist/, 'throws error on unexpected oligo name';

}

sub get_oligo_region_length : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $length = $o->get_oligo_region_length('G5'), 'can get_oligo_region_length';
    is $length, $o->G5_region_length, 'have correct oligo region length value';

    throws_ok {
        $o->get_oligo_region_length('M3')
    } qr/Attribute M3_region_length does not exist/
        , 'throws error on unexpected oligo name';

}

sub write_sequence_file : Tests(6){
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->write_sequence_file( 'A1', 'A1_test', 'ATCG' )
    } 'can write_sequence_file';

    ok my $seq_file = $o->oligo_target_regions_dir->file( 'A1.fasta' )
        ,'can create Path::Class::File object from oligo target regions directory';
    ok $o->oligo_target_regions_dir->contains( $seq_file ), 'test seq file exists';

    ok my $seq_in = Bio::SeqIO->new( -file => $seq_file->stringify, -format => 'fasta' )
        , 'can load up seq file';
    is $seq_in->next_seq->seq, 'ATCG', 'file has correct sequence';
}

sub get_sequence : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my $seq = $o->get_sequence( 1,10 );
    is $seq, 'NNNNNNNNNN', 'sequence is correct';

    throws_ok{
        $o->get_sequence( 10, 1 );
    } qr/Start must be less than end/
        , 'throws error if start after end';
}

sub _get_test_object {
    my ( $test, $strand ) = @_;
    $strand //= 1;

    return $test->test_class->new(
        dir          => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        target_start => 101176328,
        target_end   => 101176428,
        chr_name     => 11,
        chr_strand   => $strand,
    );
}

1;

__END__
