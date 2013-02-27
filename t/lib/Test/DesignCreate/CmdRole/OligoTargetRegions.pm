package Test::DesignCreate::CmdRole::OligoTargetRegions;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::OligoTargetRegions;
use DesignCreate::Cmd;

# Testing
# DesignCreate::CmdRole::OligoTargetRegions
# DesignCreate::Action::OligoTargetRegions ( through command line )
# DesignCreate::Role::TargetSequence

# Not testing this, its just a list of attributes
# DesignCreate::Role::OligoRegionParameters

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::OligoTargetRegions' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'oligo-target-regions',
        '--dir', $dir->dirname,
        '--target-start', 101176328,
        '--target-end', 101176428,
        '--chromosome', 11,
        '--strand', 1,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
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

sub get_oligo_region_coordinates : Tests(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ##
    ## Deletion / Insertion
    ##
    ok my( $u5_start, $u5_end ) = $o->get_oligo_region_coordinates( 'U5' )
        , 'can call get_oligo_region_coordinates';

    my $u5_real_start = ( $o->target_start - ( $o->U5_region_offset + $o->U5_region_length ) );
    my $u5_real_end = ( $o->target_start - ( $o->U5_region_offset + 1 ) );
    is $u5_start, $u5_real_start, 'correct start value';
    is $u5_end, $u5_real_end, 'correct end value';

    ok my( $u3_start, $u3_end ) = $o->get_oligo_region_coordinates( 'U3' )
        , 'can call get_oligo_region_coordinates';
    my $u3_real_start = ( $o->target_end + ( $o->U3_region_offset + 1 ) );
    my $u3_real_end = ( $o->target_end + ( $o->U3_region_offset + $o->U3_region_length ) );
    is $u3_start, $u3_real_start, 'correct start value';
    is $u3_end, $u3_real_end, 'correct end value';

    ok $o = $test->test_class->new(
        dir               => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute, 
        target_start      => 101176328,
        target_end        => 101176428,
        chr_name          => 11,
        chr_strand        => 1,
        U5_region_length  => 1,
    ), 'we got a object';

    throws_ok {
        !$o->get_oligo_region_coordinates( 'U5' )
    } qr/Start \d+, greater than or equal to end \d+/, 'throws start greater than end error';

}

sub build_oligo_target_regions : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->build_oligo_target_regions
    } 'can build_oligo_target_regions';

    for my $oligo ( qw( G5 U5 D3 G3 ) ) {
        my $oligo_file = $o->oligo_target_regions_dir->file( $oligo . '.fasta' );
        ok $o->oligo_target_regions_dir->contains( $oligo_file ), "$oligo oligo file exists";
    }
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
