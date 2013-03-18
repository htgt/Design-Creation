#!/usr/bin/env perl

#
# Outline of a script that can create multiple designs from information specified in a csv file
#

use strict;
use warnings FATAL => 'all';

use IPC::System::Simple qw( system );
use Text::CSV;
use Try::Tiny;
use Getopt::Long;
use List::MoreUtils qw( any );
use Smart::Comments;

my ( $file, $persist, $base_work_dir );
GetOptions(
    'file=s'      => \$file,
    'persist'     => \$persist,
    'dir=s'       => \$base_work_dir,
    'conditional' => \my $conditional,
    'debug'       => \my $debug,
    'gene=s'      => \my @genes,
    'param=s'     => \my %extra_params,
);

die( 'Specify base work dir' ) unless $base_work_dir;
die( 'Specify file with design info' ) unless $file;

open ( my $fh, '<', $file ) or die( "Can not open $file " . $! );
my $csv = Text::CSV->new();
$csv->column_names( @{ $csv->getline( $fh ) } );

while ( my $data = $csv->getline_hr( $fh ) ) {
    if ( @genes ) {
        next unless any { $data->{'target-gene'} eq $_ } @genes;
    }

    my ( $params, $dir ) = get_params( $data );
    my @args;

    push @args, $conditional ? 'conditional-design' : 'ins-del-design';
    push @args, $debug       ? '--debug'            : '--verbose';
    push @args, '--persist' if $persist;

    push @args, @{ $params };
    if ( %extra_params ) {
        while ( my( $cmd, $arg ) = each %extra_params ) {
            push @args, '--' . $cmd,;
            push @args, $arg;
        }
    }

    try{
        system( 'bin/design-create', @args );
    }
    catch{
        print $_;
    };
}

sub get_params {
    my $data = shift;

    my $dir = $base_work_dir . $data->{'target-gene'};
    my @params;
    while ( my( $cmd, $arg ) = each %{ $data } ) {
        push @params, '--' . $cmd,;
        push @params, $arg;
    }
    push @params, '--dir', $dir;

    return ( \@params, $dir );
}
