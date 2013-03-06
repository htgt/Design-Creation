package Test::DesignCreate::Action::InsDelDesign;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir );
use base qw( Test::Class Class::Data::Inheritable );

use DesignCreate::Cmd;

# Testing
# DesignCreate::Action::InsDelDesign ( through command line )

BEGIN {
    __PACKAGE__->mk_classdata( 'cmd_class' => 'DesignCreate::Cmd' );
}

sub valid_ins_del_design_aos_cmd : Test(3) {
    my $test = shift;

    my $dir = File::Temp->newdir( TMPDIR => 1, CLEANUP => 1 );

    my @argv_contents = (
        'ins-del-design',
        '--dir', $dir->dirname,
        '--target-start', 101176328,
        '--target-end', 101176428,
        '--chromosome', 11,
        '--strand', 1,
        '--target-gene', 'LBL-TEST',
        '--design-method', 'deletion',
    );

    note('############################################');
    note('Following test may take a while to finish...');
    note('############################################');
    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

1;

__END__
