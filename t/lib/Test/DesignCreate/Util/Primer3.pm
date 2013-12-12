package Test::DesignCreate::Util::Primer3;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use FindBin;
use Path::Class qw( tempdir dir );
use Bio::Seq;
use base qw( Test::Class Class::Data::Inheritable );

# use_ok ?
use LIMS2::Util::EnsEMBL;
use DesignCreate::Util::Primer3;

# Testing
# DesignCreate::Util::Primer3

BEGIN {
    __PACKAGE__->mk_classdata( 'class' => 'DesignCreate::Util::Primer3' );
}

sub constructor : Test(startup => 2) {
    my $test = shift;

    ok my $o = $test->class->new_with_config(
        configfile               => _get_test_data_file( 'primer3_config.yaml' ),
        primer_lowercase_masking => 1,
    ), 'we got a object';

    isa_ok $o, $test->class;

    $test->{o} = $o;
}

sub run_primer : Test(7) {
    my $test = shift;
    ok my $o = $test->{o}, 'can grab test object';

    # Setup test input
    my $temp_dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $log_file = $temp_dir->file( 'primer3_test_output.log' );

    my $ensembl_util = LIMS2::Util::EnsEMBL->new( species => 'Human' );
    my $slice = $ensembl_util->slice_adaptor->fetch_by_region(
        'chromosome',
        11,
        118962764,
        118964363,
    );
    my $region_bio_seq = Bio::Seq->new( -display_id => 'test_region', -seq => $slice->seq );

    throws_ok{
        $o->run_primer3( undef, $region_bio_seq, {} )
    } qr/\$outfile variable must be Path::Class::File object/
        , 'first input to run_primer3 must be a Path::Class::File object';

    throws_ok{
        $o->run_primer3( $log_file, undef, {} )
    } qr/\$seq variable must be Bio::SeqI object/
        , 'second input to run_primer3 must be a Bio::SeqI object';

    throws_ok{
        $o->run_primer3( $log_file, $region_bio_seq, [] )
    } qr/\$target variable must be a hashref or undef/
        , 'third input to run_primer3 must be a hashref or under';

    ok my ( $result, $primer3_explain )
        = $o->run_primer3( $log_file->absolute, $region_bio_seq, { SEQUENCE_TARGET => '500,500' } ),
        'can call run_primer3';

    isa_ok $result, 'Bio::Tools::Primer3Redux::Result', '.. and got the correct object returned';

    # this will have errors
    ok! $o->run_primer3( $log_file->absolute, Bio::Seq->new( -seq => 'ATCG' ) )
        ,'fails to return result if primer3 encounters any errors';

}

sub _get_test_data_file {
    my ( $filename ) = @_;
    my $data_dir = dir($FindBin::Bin)->subdir('test_data/primer3/');
    my $file = $data_dir->file($filename);

    return $file->stringify;
}

1;

__END__
