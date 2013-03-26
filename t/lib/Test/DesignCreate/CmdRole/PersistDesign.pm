package Test::DesignCreate::CmdRole::PersistDesign;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Test::MockObject;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::PersistDesign ( through command line ) # NO
# DesignCreate::CmdRole::PersistDesign

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::PersistDesign' );
}

sub persist_design : Test(10) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok !$o->have_alt_designs_file, 'do not have a alt designs file set';
    lives_ok{
        $o->persist_design;
    } 'can persist_design';
    ok !$o->have_alt_designs_file, 'stll do not have a alt designs file set';

    ok $o = $test->_get_test_object( { alternate_designs => 1 } ), 'can grab another test object';
    ok !$o->have_alt_designs_file, 'do not have a alt designs file set';
    lives_ok{
        $o->persist_design;
    } 'can persist_design';
    ok $o->have_alt_designs_file, 'we have a alt designs file set';
    ok my $alt_design_data = $o->alternate_designs_data, 'we have alternate design data';
    is scalar( @{ $alt_design_data } ), 2, 'have 2 alternate designs';
}


sub _persist_design : Test(5) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $design_data = LoadFile( $o->dir->file( 'design_data.yaml' ) ), 'can load design data file';

    lives_ok{
        $o->_persist_design( $design_data );
    } 'can call _persist_design';

    my $mock_api = $o->lims2_api;
    $mock_api->called_ok( 'POST', 'called POST on lims2_api' );

    $mock_api->called_args_pos_is( 1, 2, 'design', 'we are sending design as the first argument to POST' );
}

sub set_alternate_designs_data_file : Test(9) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok !$o->have_alt_designs_file, 'do not have a alt designs file set';
    lives_ok{
        $o->set_alternate_designs_data_file
    } 'can call set_alternate_designs_data_file';
    ok $o->have_alt_designs_file, 'alt designs file is now set';

    ok $o = $test->_get_test_object, 'can grab another test object';

    ok $o->dir->file('alt_designs.yaml')->remove, 'can remove alt designs yaml file';

    ok !$o->have_alt_designs_file, 'do not have a alt designs file set';
    lives_ok{
        $o->set_alternate_designs_data_file
    } 'can call set_alternate_designs_data_file';
    ok !$o->have_alt_designs_file, 'alt designs file is still not set';
}

sub _get_test_object {
    my ( $test, $params ) = @_;
    my $alt_designs = $params->{alternate_designs} || 0;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/persist_design');

    dircopy( $data_dir->stringify, $dir->stringify );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        lims2_api         => $test->_get_mock_lims2_api,
        dir               => $dir,
        alternate_designs => $alt_designs,
        design_method     => 'deletion',
    );
}

sub _get_mock_lims2_api {
    my $test = shift;

    my $mock_lims2_api = Test::MockObject->new;
    $mock_lims2_api->set_isa( 'LIMS2::REST::Client' );
    $mock_lims2_api->mock( 'POST', sub{ { id => 123 } } );

    return $mock_lims2_api;
}

1;

__END__
