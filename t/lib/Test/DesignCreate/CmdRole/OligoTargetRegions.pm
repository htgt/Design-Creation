package Test::DesignCreate::CmdRole::OligoTargetRegions;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use File::Temp;
use App::Cmd::Tester;
use Path::Class qw( dir );
use Bio::SeqIO;
use base qw( Test::Class Class::Data::Inheritable );

use Test::DesignCreate;
use DesignCreate::Cmd;

# Testing
# DesignCreate::CmdRole::OligoTargetRegions
# DesignCreate::Action::OligoTargetRegions ( through command line )

# Not testing this, its just a list of attributes
# DesignCreate::Role::OligoRegionParameters

BEGIN {
    __PACKAGE__->mk_classdata( 'class' => 'DesignCreate::Cmd' );
}

sub valid_run_cmd : Test(no_plan) {
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

    ok my $result = test_app($test->class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
}

sub constructor : Test(startup => 3) {
    my $test = shift;

    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    ok my $o = Test::DesignCreate->new(
        dir          => dir( $dir->dirname ),
        target_start => 101176328,
        target_end   => 101176428,
        chr_name     => 11,
        chr_strand   => 1,
    ), 'we got a object';

    is $o->dir->stringify, $dir->dirname, 'correct working dir';
    is $o->design_method, 'deletion', 'correct design_method';

    $test->{o} = $o;
}

sub get_oligo_region_offset : Tests(2) {
    my $test = shift;

    ok $test->{o}->get_oligo_region_offset('G5'), 'can get_oligo_region_offset';
    throws_ok { $test->{o}->get_oligo_region_offset('M3') }
        qr/Attribute M3_region_offset does not exist/, 'throws error on unexpected oligo name';

} 

sub get_oligo_region_length : Tests(2) {
    my $test = shift;

    ok $test->{o}->get_oligo_region_length('G5'), 'can get_oligo_region_length';

    throws_ok {
        $test->{o}->get_oligo_region_length('M3')
    } qr/Attribute M3_region_length does not exist/
        , 'throws error on unexpected oligo name';

} 

sub write_sequence_file : Tests(5){
    my $test = shift;

    lives_ok {
        $test->{o}->write_sequence_file( 'A1', 'A1_test', 'ATCG' )
    } 'can write_sequence_file';

    ok my $seq_file = $test->{o}->oligo_target_regions_dir->file( 'A1.fasta' )
        ,'can create Path::Class::File object from oligo target regions directory';
    ok $test->{o}->oligo_target_regions_dir->contains( $seq_file ), 'test seq file exists';

    ok my $seq_in = Bio::SeqIO->new( -file => $seq_file->stringify, -format => 'fasta' ), 'can load up seq file';
    is $seq_in->next_seq->seq, 'ATCG', 'file has correct sequence';
}

sub get_oligo_region_coordinates : Tests(no_plan) {
    my $test = shift;

    ok my( $start, $end ) = $test->{o}->get_oligo_region_coordinates( 'U5' )
        , 'can call get_oligo_region_coordinates';

    my $dir = File::Temp->newdir( TMPDIR => 1 );
    ok my $o = Test::DesignCreate->new(
        dir               => dir( $dir->dirname ),
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

sub build_oligo_target_regions : Test(5) {
    my $test = shift;

    lives_ok {
        $test->{o}->build_oligo_target_regions
    } 'can build_oligo_target_regions';

    for my $oligo ( qw( G5 U5 D3 G3 ) ) {
        my $oligo_file = $test->{o}->oligo_target_regions_dir->file( $oligo . '.fasta' );
        ok $test->{o}->oligo_target_regions_dir->contains( $oligo_file ), "$oligo oligo file exists";
    }
} 

1;

__END__
