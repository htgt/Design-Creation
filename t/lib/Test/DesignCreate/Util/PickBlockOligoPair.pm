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

sub right_oligo_data : Test(9) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    ok my @right_oligos = $o->right_oligos, 'can get right oligos';
    is $right_oligos[0]->{oligo}, 'U3', 'correct oligo type for +ve stranded design';

    ok my @sorted_oligos = sort( { $a->{offset} <=> $b->{offset} } @right_oligos ), 'sort oligo data';
    lives_ok {
        $o->get_oligo_pairs
    } 'can call get_oligo_pairs';

    is_deeply $o->right_oligo_data, \@sorted_oligos, 'right oligos sorted correctly';

    ok $o = $test->get_test_object( { strand => -1 } ), 'can get another test object';
    ok @right_oligos = $o->right_oligos, 'can get right oligos again';
    is $right_oligos[0]->{oligo}, 'U5', 'correct oligo type for -ve stranded design';
}

sub left_oligo_data : Test(9) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    ok my @left_oligos = $o->left_oligos, 'can get left oligos';
    is $left_oligos[0]->{oligo}, 'U5', 'correct oligo type for +ve stranded design';

    ok my @sorted_oligos = sort( { $b->{offset} <=> $a->{offset} } @left_oligos ), 'sort oligo data';
    lives_ok {
        $o->get_oligo_pairs
    } 'can call get_oligo_pairs';

    is_deeply $o->left_oligo_data, \@sorted_oligos, 'left oligos sorted correctly';

    ok $o = $test->get_test_object( { strand => -1 } ), 'can get another test object';
    ok @left_oligos = $o->left_oligos, 'can get left oligos again';
    is $left_oligos[0]->{oligo}, 'U3', 'correct oligo type for -ve stranded design';
}

sub get_oligo_pairs : Test(11) {
    my $test = shift;
    ok my $o = $test->get_test_object, 'can get test object';

    #default min_gap 15 makes the U3-10, U5-13 pair invalid, their gap is 14
    ok my $oligo_pairs = $o->get_oligo_pairs,  'can call get_oligo_pairs';

    my $best_pair = shift @{ $oligo_pairs };
    is_deeply $best_pair, { U5 => 'U5-13', U3 => 'U3-9' }, 'have correct best pair';

    #min_gap 10 makes teh U3-10, U5-13 pair valid, their gap is 14
    ok $o = $test->get_test_object( { min_gap => 10 } ), 'can get another test object';
    ok $oligo_pairs = $o->get_oligo_pairs,  'can call get_oligo_pairs';

    $best_pair = shift @{ $oligo_pairs };
    is_deeply $best_pair, { U5 => 'U5-13', U3 => 'U3-10' }, 'have correct best pair';

    ok my $d_o = $test->get_test_object( { five_file => 'D5.yaml', three_file => 'D3.yaml' } ),
        'can get test object for D oligos';

    ok my $d_oligo_pairs = $d_o->get_oligo_pairs,  'can call get_oligo_pairs';
    is_deeply $d_oligo_pairs, [], 'no valid pairs';

    ok my $f_o = $test->get_test_object( { strand => -1 } ), 'can get test object with wrong strand';
    throws_ok{
        $f_o->get_oligo_pairs
    } qr/Invalid input/, 'throws error when 5 and 3 oligos wrong way around for given strand';
}

sub get_test_object {
    my ( $test, $params ) = @_;
    my $strand     = $params->{strand} || 1;
    my $min_gap    = $params->{min_gap} || 15;
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
