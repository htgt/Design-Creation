package Test::DesignCreate::Util::PickBlockOligoPair;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use FindBin;
use Path::Class qw( dir );
use base qw( Test::Class Class::Data::Inheritable );

use DesignCreate::Util::PickBlockOligoPair;

# Testing
# DesignCreate::Util::PickBlockOligoPair

BEGIN {
    __PACKAGE__->mk_classdata( 'class' => 'DesignCreate::Util::PickBlockOligoPair' );
}

sub constructor : Test( startup => 2) {
    my $test = shift;
    my $o;

    lives_ok {
        $o = $test->get_test_object()
    } 'can create test object';

    isa_ok $o, $test->class;
}

sub right_oligos : Test(6) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    ok my $right_oligos = $o->right_oligos, 'can get right oligos';
    is $right_oligos->[0]{oligo}, 'U3', 'correct oligo type for +ve stranded design';

    ok $o = $test->get_test_object( { strand => -1 } ), 'can get another test object';
    ok $right_oligos = $o->right_oligos, 'can get right oligos again';
    is $right_oligos->[0]->{oligo}, 'U5', 'correct oligo type for -ve stranded design';
}

sub left_oligos : Test(6) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    ok my $left_oligos = $o->left_oligos, 'can get left oligos';
    is $left_oligos->[0]->{oligo}, 'U5', 'correct oligo type for +ve stranded design';

    ok $o = $test->get_test_object( { strand => -1 } ), 'can get another test object';
    ok $left_oligos = $o->left_oligos, 'can get left oligos again';
    is $left_oligos->[0]->{oligo}, 'U3', 'correct oligo type for -ve stranded design';
}

sub get_oligo_pairs : Test(13) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    # optimal gap is 30, best pair has gap of 32
    ok my $oligo_pairs = $o->get_oligo_pairs,  'can call get_oligo_pairs';

    my $best_pair = shift @{ $oligo_pairs };
    is $best_pair->{U5}, 'U5-14', 'have correct U5 oligo for best pair';
    is $best_pair->{U3}, 'U3-11', 'have correct U3 oligo for best pair';

    #min_gap 40 makes the previous best pair invalid, their gap is 32
    ok $o = $test->get_test_object( { min_gap => 40 } ), 'can get another test object';
    ok $oligo_pairs = $o->get_oligo_pairs,  'can call get_oligo_pairs';

    $best_pair = shift @{ $oligo_pairs };
    is $best_pair->{U5}, 'U5-11', 'have correct U5 oligo for best pair';
    is $best_pair->{U3}, 'U3-9', 'have correct U3 oligo for best pair';

    # return pair for -ve stranded design
    ok my $d_o = $test->get_test_object( { five_file => 'D5.yaml', three_file => 'D3.yaml', strand => -1 } ),
        'can get test object for D oligos';

    ok my $d_oligo_pairs = $d_o->get_oligo_pairs,  'can call get_oligo_pairs';
    ok $d_o->have_oligo_pairs, 'have valid D pairs';
    $best_pair = shift @{ $d_oligo_pairs };
    is $best_pair->{D5}, 'D5-1', 'have correct D5 oligo for best pair';
    is $best_pair->{D3}, 'D3-4', 'have correct D3 oligo for best pair';

}

sub check_oligo_pair : Test(10) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    my $left_oligo = shift @{ $o->left_oligos };
    my $right_oligo = shift @{ $o->right_oligos };

    ok !$o->check_oligo_pair( $right_oligo, $left_oligo )
        , 'check_oligo_pair with oligos in wrong order';
    ok !$o->have_oligo_pairs, 'pairs array has no a value';

    $right_oligo->{oligo_start} = 10000079;
    lives_ok{
        $o->check_oligo_pair( $left_oligo, $right_oligo )
    } 'can call check_oligo_pair';
    ok !$o->have_oligo_pairs, 'pairs array has no a value, when min_gap value specified';

    $right_oligo->{oligo_start} = 10000132;
    lives_ok{
        $o->check_oligo_pair( $left_oligo, $right_oligo )
    } 'can call check_oligo_pair';
    ok $o->have_oligo_pairs, 'pairs array has a value, min_gap specified and gap is larger than this';

    ok $o = $test->get_test_object( { min_gap => undef } ), 'can get test object';
    $right_oligo->{oligo_start} = 10000079;
    lives_ok{
        $o->check_oligo_pair( $left_oligo, $right_oligo )
    } 'can call check_oligo_pair';
    ok $o->have_oligo_pairs, 'pairs array has a value when no min_gap value specified';
}

sub get_test_object {
    my ( $test, $params ) = @_;
    my $strand     = $params->{strand} || 1;
    my $min_gap    = exists $params->{min_gap} ? $params->{min_gap} : 15;
    my $five_file  = $params->{five_file} || 'U5.yaml';
    my $three_file = $params->{three_file} ||'U3.yaml';

    my $o = $test->class->new(
        five_prime_oligo_file  => _get_test_data_file( $five_file ),
        three_prime_oligo_file => _get_test_data_file( $three_file ),
        min_gap                => $min_gap,
        strand                 => $strand,
    );

    return $o;
}

sub _get_test_data_file {
    my ( $filename ) = @_;
    my $data_dir = dir($FindBin::Bin)->subdir('test_data/pick_block_oligo_pair_data/');
    my $file = $data_dir->file($filename);

    return $file;
}

1;

__END__
