package Test::DesignCreate::Action::InsDelDesign;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir );
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::InsDelDesign ( through command line )

sub valid_ins_del_design_aos_cmd : Test(4) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    my @argv_contents = (
        'ins-del-design'  ,
        '--dir'           , $dir->stringify,
        '--target-start'  , 101176328,
        '--target-end'    , 101176428,
        '--chromosome'    , 11,
        '--strand'        , 1,
        '--target-gene'   , 'LBL-TEST',
        '--design-method' , 'deletion',
    );

    note('############################################');
    note('Following test may take a while to finish...');
    note('############################################');
    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    is $result->stderr, '', 'no errors';
    ok !$result->error, 'no command errors';

    my $data_file = $dir->file('design_data.yaml');
    ok $dir->contains( $data_file ), 'design data file exists';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

1;

__END__
