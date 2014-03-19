package Test::DesignCreate::Role::Common;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use base qw( Test::DesignCreate::CmdStep Class::Data::Inheritable );

# Testing
# DesignCreate::Role::Common

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::Common' );
}

sub get_file : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';
    my $dir = $o->dir;

    ok my $file = $o->get_file( 'design_parameters.yaml', $dir ), 'can use get_file';
    isa_ok $file, 'Path::Class::File';

    throws_ok{
        $o->get_file( 'blah.yaml', $dir )
    } 'DesignCreate::Exception::MissingFile'
        , 'throws error for missing file';
}

sub oligos : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $deletion_oligos = [ $o->expected_oligos ], 'can call expected_oligos';
    is_deeply $deletion_oligos, [ qw( G5 U5 D3 G3 ) ], 'have correct deletion oligos';

    ok my $c_o = $test->_get_test_object, 'can grab test object';
    ok $c_o->set_param( 'design_method', 'conditional' ), 'can set design method to conditional'; 
    ok my $conditional_oligos = [ $c_o->expected_oligos ], 'can call expected_oligos';
    is_deeply $conditional_oligos, [ qw( G5 U5 U3 D5 D3 G3 ) ], 'have correct conditional oligos';

    ok my $o_o = $test->_get_test_object, 'can grab test object';
    ok $o_o->set_param( 'design_method', 'blah' ), 'can set design method to conditional'; 
    throws_ok{
        $o_o->expected_oligos
    } qr/Unknown design method blah/
        ,'throws error for unknown design method';
}

sub add_design_parameters : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->add_design_parameters( [ 'design_data_file_name' ] )
    } 'can add design parameter';

    throws_ok{
        $o->add_design_parameters( [ 'blah' ] )
    } 'DesignCreate::Exception::NonExistantAttribute'
        ,'throws error when trying to set non existant attribute as a design parameter';

}

sub design_param : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    is $o->design_param( 'design_method' ), 'deletion', 'can call design_param';

    throws_ok{
        $o->design_param( 'blah' )
    } qr/blah not stored in design parameters hash or attribute value/
        ,'throws error when trying to find non existant design parameter value';

}

sub _get_test_object {
    my ( $test ) = @_;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    # just want some data to test against, don't care what data
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/consolidate_design_data');
    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object( dir => $dir );
}

1;

__END__
