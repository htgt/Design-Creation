package Test::DesignCreate::CmdRole::FetchOligoRegionsSequence;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use FindBin;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole::FetchOligoRegionsSequence
# DesignCreate::Cmd::Step::FetchOligoRegionsSequence ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::FetchOligoRegionsSequence' );
}

sub valid_run_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'fetch-oligo-regions-sequence',
        '--dir', $o->dir->stringify,
        '--design-method', 'deletion',
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub create_oligo_region_sequence_files : Test(11) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->create_oligo_region_sequence_files
    } 'can build_oligo_target_regions';

    for my $oligo ( qw( G5 U5 D3 G3 ) ) {
        my $oligo_file = $o->oligo_target_regions_dir->file( $oligo . '.fasta' );
        ok $o->oligo_target_regions_dir->contains( $oligo_file ), "$oligo oligo file exists";
    }

    lives_ok{
        delete $o->oligo_region_data->{G5}
    } 'can delete G5 oligo region data';

    throws_ok{
        $o->create_oligo_region_sequence_files
    } qr/No oligo region coordinate information found for G5 oligo region/
        ,'throws error when we are missing oligo region coordinate information';

    ok $o = $test->_get_test_object, 'can grab another test object';
    ok $o->oligo_target_regions_dir->file( 'oligo_region_coords.yaml' )->remove
        , 'can remove oligo region coordinate file';

    throws_ok {
        $o->create_oligo_region_sequence_files
    } 'DesignCreate::Exception::MissingFile' 
        , 'can build_oligo_target_regions';
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

sub _get_test_object {
    my ( $test, $strand ) = @_;
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/fetch_oligo_regions_sequence');
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir => $dir,
    );
}

1;

__END__
