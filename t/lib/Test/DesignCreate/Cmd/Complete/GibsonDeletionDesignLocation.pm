package Test::DesignCreate::Cmd::Complete::GibsonDeletionDesignLocation;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use App::Cmd::Tester;
use Path::Class qw( tempdir );
use base qw( Test::DesignCreate::CmdComplete Class::Data::Inheritable );

# Testing
# DesignCreate::Cmd::Complete::GibsonDeletionDesignLocation ( through command line )

sub gibson_design_cmd : Test(4) {
    my $test = shift;

    my $dir = tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute;

    my @argv_contents = (
        'gibson-deletion-design-location'         ,
        '--dir'                 , $dir->stringify,
        '--species'             , 'Human',
        '--target-gene'         , 'GIBSON',
        '--target-end'          , 118966177,
        '--target-start'        , 118964564,
        '--strand'              , -1,
        '--chromosome'          , 11,
        '--region-offset-er-3f' , 50,
    );

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
