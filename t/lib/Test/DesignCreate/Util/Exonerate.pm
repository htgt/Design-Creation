package Test::DesignCreate::Util::Exonerate;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use FindBin;
use Path::Class qw( dir );
use base qw( Test::Class Class::Data::Inheritable );

use DesignCreate::Util::Exonerate;

# Testing
# DesignCreate::Util::Exonerate

BEGIN {
    __PACKAGE__->mk_classdata( 'class' => 'DesignCreate::Util::Exonerate' );
}

sub constructor : Test(startup => 2) {
    my $test = shift;

    ok my $o = $test->class->new(
        target_file => _get_test_data_file('target.fasta'),
        query_file  => _get_test_data_file('query.fasta'),
    ), 'we got a object';

    isa_ok $o, $test->class;

    $test->{o} = $o;
}

sub run_exonerate : Test(3) {
    my $test = shift;

    lives_ok{
        $test->{o}->run_exonerate
    } 'can run_exonerate';

    my $first_result = shift @{ $test->{o}->exonerate_results };
    like $first_result, qr/^RESULT: /, 'result line as expected';

    my $o = $test->class->new(
        target_file => _get_test_data_file('target.fasta'),
        query_file  => _get_test_data_file('false_query.fasta'),
    );

    throws_ok{
        $o->run_exonerate
    } qr/Failed to run exonerate: /,
        'throws error for invalid input';
}

sub parse_exonerate_output : Test(11) {
    my $test = shift;

    lives_ok{
        $test->{o}->run_exonerate;
        $test->{o}->parse_exonerate_output;
    } 'can parse_exonerate_output';

    ok my $matches = $test->{o}->matches, 'have matches';

    ok my $d31_match = $matches->{'D3-1'}, 'we have D3-1 match results';
    is $d31_match->{hits}, 1, 'have one hit';
    is $d31_match->{exact_matches}, 1, 'have one exact hit';

    my $o = $test->class->new(
        target_file => _get_test_data_file('wrong_target.fasta'),
        query_file  => _get_test_data_file('query.fasta'),
    );

    lives_ok{
        $o->parse_exonerate_output;
    } 'can parse_exonerate_output';

    ok !$o->matches, 'no matches, have not run exonerate yet';

    lives_ok{
        $o->run_exonerate;
        $o->parse_exonerate_output;
    } 'can run_exonerate and parse_exonerate_output';

    ok !$o->matches, 'no matches, wrong target file';
    
    $o = $test->class->new(
        target_file => _get_test_data_file('target.fasta'),
        query_file  => _get_test_data_file('query.fasta'),
        ryo         => "RESULT: %qi %qal %ql %pi %s %em\n",
    );

    lives_ok{
        $o->run_exonerate;
    } 'can run_exonerate';

    throws_ok{
        $o->parse_exonerate_output
    } qr/Cannot return matches if RYO attribute/
        ,'can not call parse_exonerate_output when specifying custon ryo value'
}

sub _get_test_data_file {
    my ( $filename ) = @_;
    my $data_dir = dir($FindBin::Bin)->subdir('test_data/exonerate_data/');
    my $file = $data_dir->file($filename);

    return $file->stringify;
}

1;

__END__
