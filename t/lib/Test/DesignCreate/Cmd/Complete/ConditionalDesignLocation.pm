package Test::DesignCreate::Cmd::Complete::ConditionalDesignLocation;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir );
use base qw( Test::DesignCreate::CmdComplete Class::Data::Inheritable );

# Testing
# DesignCreate::Cmd::Complete::ConditionalDesignLocation ( through command line )

sub conditional_design_cmd : Test(4) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    my @argv_contents = (
        'conditional-design-location'  ,
        '--dir'               , $dir->stringify,
        '--species'           , 'Mouse',
        '--chromosome'        , 11,
        '--strand'            , 1,
        '--target-start'      , 10000400,
        '--target-end'        , 10000450,

        '--region-length-u-block'  , 200,
        '--region-offset-u-block'  , 200,
        '--region-overlap-u-block' , 10,
        '--region-length-d-block'  , 200,
        '--region-offset-d-block'  , 100,
        '--region-overlap-d-block' , 10,

        '--target-gene'       , 'CONDITIONAL-TEST',
        '--mask-by-lower-case', 'no',
    );

    note('############################################');
    note('Following test may take a while to finish...');
    note('############################################');
    ok my $result = test_app($test->cmd_class => \@argv_contents), 'can run command';

    #is $result->stderr, '', 'no errors';  Was directed at /lustre/ TODO reroute to local fasta files

    ok !$result->error, 'no command errors';

    my $data_file = $dir->file('design_data.yaml');
    #ok $dir->contains( $data_file ), 'design data file exists';

    #change out of tmpdir so File::Temp can delete the tmp dir
    chdir;
}

1;

__END__
