package Test::DesignCreate::CmdRole::TargetLocation;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use YAML::Any qw( LoadFile );
use Bio::SeqIO;
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::CmdRole:TargetLocation
# DesignCreate::Cmd::Step::TargetLocation ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::TargetLocation' );
}

sub valid_run_cmd : Test(3) {
    my $test = shift;

    #create temp dir in standard location for temp files
    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 );

    #note: small chance with new ensembl build that we will need
    #      to update the exon id
    my @argv_contents = (
        'target-location',
        '--dir'          ,$dir->stringify,
        '--target-gene'  ,'test_gene',
        '--species'      ,'Human',
        '--target-start' , 5000,
        '--target-end'   , 5500,
        '--strand'       , 1,
        '--chromosome'   , 11,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub verify_target_coordinates : Tests(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->verify_target_coordinates
    } 'can verify target coordinates';

    my $metaclass = $test->get_test_object_metaclass();

    my $new_obj = $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        target_start    => 5500,
        target_end      => 5000,
        chr_strand      => 1,
        chr_name        => 9,
        target_genes    => [ 'test_gene' ],
    );

    throws_ok{
        $new_obj->verify_target_coordinates
    } qr/Target start: 5500 is greater than target end: 5000/
        , 'throws error if targets start is before end';
}

sub create_target_coordinate_file : Test(6) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok {
        $o->target_coordinates
    } 'can get_oligo_pair_region_coordinates';

    my $target_file = $o->oligo_target_regions_dir->file( 'target_coords.yaml' );
    ok $o->oligo_target_regions_dir->contains( $target_file )
        , "$target_file file exists";

    ok my $target_data = LoadFile( $target_file ), 'can load data from target file';

    is $target_data->{target_start}, 5000, '.. target_start is correct';
    is $target_data->{chr_name}, 9, '.. chr_name is correct';
}

sub chr_name : Test(3) {
    my $test = shift;

    throws_ok{
        $test->_get_test_object( { chr_strand => -1, chr_name => 30 } )
    } qr/Invalid chromosome name, 30/, 'throws error with invalid chromosome name';

    throws_ok{
        $test->_get_test_object( { chr_strand => -1, chr_name => 'Z'} )
    } qr/Invalid chromosome name, Z/, 'throws error with invalid chromosome name';

    lives_ok{
        $test->_get_test_object( { chr_strand => -1, chr_name => 'y'} )
    } 'valid chromosome okay';
}

sub chr_strand : Test(3) {
    my $test = shift;

    throws_ok{
        $test->_get_test_object( { chr_strand => 2, chr_name => '3'} )
    } qr/Invalid strand 2/, 'throws error with invalid chromosome strand';

    throws_ok{
        $test->_get_test_object( { chr_strand => -2, chr_name => 'X' } )
    } qr/Invalid strand -2/, 'throws error with invalid chromosome strand';

    lives_ok{
        $test->_get_test_object( { chr_strand => -1, chr_name => 'X' } )
    } 'valid strand okay';
}

sub _get_test_object {
    my ( $test, $params ) = @_;

    my $chr_name   = $params->{chr_name} ? $params->{chr_name} : 9;
    my $chr_strand = $params->{chr_strand} ? $params->{chr_strand} : 1;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir             => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        species         => 'Human',
        target_start    => 5000,
        target_end      => 5500,
        chr_strand      => $chr_strand,
        chr_name        => $chr_name,
        target_genes    => [ 'test_gene' ],
    );
}

1;

__END__
