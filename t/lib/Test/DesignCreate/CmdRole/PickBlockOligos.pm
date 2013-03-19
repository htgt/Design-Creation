package Test::DesignCreate::CmdRole::PickBlockOligos;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir dir );
use File::Copy::Recursive qw( dircopy );
use YAML::Any qw( LoadFile );
use FindBin;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::PickBlockOligos ( through command line )
# DesignCreate::CmdRole::PickBlockOligos, most of its work is done by:

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::CmdRole::PickBlockOligos' );
}

sub valid_pick_gap_oligos_cmd : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    my @argv_contents = (
        'pick-block-oligos',
        '--dir'            , $o->dir->stringify,
        '--design-method'  , 'conditional',
        '--strand'         , 1,
        '--chromosome'     , 11,
    );

    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';
}

sub pick_block_oligos : Test(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    lives_ok{
        $o->pick_block_oligos
    } 'can call pick_block_oligos';

    my $U_oligo_pairs_file = $o->validated_oligo_dir->file('U_oligo_pairs.yaml');
    my $D_oligo_pairs_file = $o->validated_oligo_dir->file('D_oligo_pairs.yaml');
    ok $o->validated_oligo_dir->contains( $D_oligo_pairs_file ), 'created D oligo pairs file';
    ok $o->validated_oligo_dir->contains( $U_oligo_pairs_file ), 'created U oligo pairs file';
}

sub pick_block_oligo_pair : Test(8) {
    my $test = shift;
    ok my $o = $test->_get_test_object( { min_gap => 20 } ), 'can grab test object';

    lives_ok{
        $o->pick_block_oligo_pair( 'U' )
    } 'can call pick_block_oligo_pair for U region';

    my $U_oligo_pairs_file = $o->validated_oligo_dir->file('U_oligo_pairs.yaml');
    ok $o->validated_oligo_dir->contains( $U_oligo_pairs_file ), 'created U oligo pairs file';

    throws_ok{
        $o->pick_block_oligo_pair( 'X' )
    } qr/Attribute min_X_oligo_gap does not exist/, 'throws error for invalid oligo type';

    throws_ok{
        $o->pick_block_oligo_pair( 'D' )
    } qr/No valid oligo pairs for D oligo region/
        , 'throws error when no valid oligo pairs found';

    ok $o = $test->_get_test_object( ), 'can grab test object';
    lives_ok{
        $o->pick_block_oligo_pair( 'D' )
    } 'can call pick_block_oligo_pair for D oligo region with min_gap 10';

    my $D_oligo_pairs_file = $o->validated_oligo_dir->file('D_oligo_pairs.yaml');
    ok $o->validated_oligo_dir->contains( $D_oligo_pairs_file ), 'created D oligo pairs file';
}

sub _get_test_object {
    my ( $test, $params ) = @_;
    my $min_gap = $params->{min_gap} || 10;
    my $strand = $params->{strand} || 1;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;
    my $data_dir = dir($FindBin::Bin)->absolute->subdir('test_data/pick_block_oligos_data');

    dircopy( $data_dir->stringify, $dir->stringify . '/validated_oligos' );

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir             => $dir,
        chr_strand      => $strand,
        chr_name        => 11,
        min_U_oligo_gap => $min_gap,
        min_D_oligo_gap => $min_gap,
        design_method   => 'deletion',
    );
}

1;

__END__
