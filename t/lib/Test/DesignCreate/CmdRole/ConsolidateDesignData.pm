package Test::DesignCreate::CmdRole::ConsolidateDesignData;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::Class Class::Data::Inheritable );

use Test::ObjectRole::DesignCreate::ConsolidateDesignData;
use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::ConsolidateDesignData ( through command line )
# DesignCreate::CmdRole::ConsolidateDesignData, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
    __PACKAGE__->mk_classdata( 'test_class' => 'Test::ObjectRole::DesignCreate::ConsolidateDesignData' );
}

sub valid_consolidate_design_data_cmd : Test(3) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'consolidate-design-data',
        '--dir', $o->dir->stringify,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
}

sub build_oligo_array : Test(no_plan) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->build_oligo_array
    } 'can call build_oligo_array';

    ok $o->picked_oligos, 'have array of picked oligos';

    ok $o->validated_oligo_dir->file( 'G5.yaml' )->remove, 'can remove G5 oligo file';
    throws_ok{
        $o->build_oligo_array
    } qr/Can't find G5 oligo file/ , 'throws error on missing oligo file';

}

sub get_oligo : Test(no_plan) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $u5_file = $o->validated_oligo_dir->file( 'U5.yaml' ), 'can find U5 oligo file';
    my $oligos = LoadFile( $u5_file );
    my @all_u5_oligos = @{ $oligos };

    ok my $oligo_data = $o->get_oligo( $oligos, 'U5' ), 'can call get_oligo';

    is $oligo_data->{seq}, $all_u5_oligos[0]{oligo_seq}
        , 'have expected U5 oligo seq, first in list';

    #TODO
    # test G5 and G3 oligo pick
}

sub format_oligo_data : Test(no_plan) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

}

sub create_design_file : Test(no_plan) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

}

sub _get_test_object {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/consolidate_design_data');

    dircopy( $data_dir->stringify, $dir->stringify . '/validated_oligos' );

    return $test->test_class->new(
        dir          => $dir,
        target_genes => [ 'LBL-1' ],
        chr_name     => 11,
        chr_strand   => 1,
    );
}

1;

__END__
