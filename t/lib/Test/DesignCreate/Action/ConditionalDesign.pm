package Test::DesignCreate::Action::ConditionalDesign;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir );
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Action::ConditionalDesign ( through command line )

sub valid_conditional_design_aos_cmd : Test(4) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    my @argv_contents = (
        'conditional-design'  ,
        '--dir'               , $dir->stringify,
        '--chromosome'        , 11,
        '--strand'            , 1,
        '--u-block-start'     , 10000100,
        '--u-block-end'       , 10000300,
        '--d-block-start'     , 10000500,
        '--d-block-end'       , 10000700,
        '--target-gene'       , 'CONDITIONAL-TEST',
        '--mask-by-lower-case', 'no',
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
