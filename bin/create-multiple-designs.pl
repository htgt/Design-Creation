#!/usr/bin/env perl

#
# Outline of a script that can create multiple designs from information specified in a csv file
#

use strict;
use warnings FATAL => 'all';

use IPC::System::Simple qw( capture );
use Perl6::Slurp;
use Path::Class;
use Fcntl; # O_ constants
use Try::Tiny;

my $base_work_dir = 'test_test/';

my @lines = split /\n/, slurp( $ARGV[0] );

for my $line ( @lines ) {
    my ( $params, $dir ) = get_params( $line );

    my @args = (
        'ins-del-design',
        '--verbose',
    );

    push @args, @{ $params }; 
    my $output;

    try{
        $output = capture( 'bin/design-create', @args );
    }
    catch{
        print $_;
    };

    my $work_dir = dir( $dir )->absolute;
    my $output_file = $work_dir->file( 'output.txt' );
    $output_file->touch;
    my $fh = $output_file->open( O_WRONLY|O_CREAT ) or die( "Open $output_file: $!" );
    print $fh $output;
}

sub get_params {
    my $line = shift;

    $line =~ s/"//g;

    my ( $gene, $position ) = split /,/, $line;
    my ( $chr, $coords ) = split /:/, $position;
    $chr =~ s/chr//;
    my ( $start, $end ) = split /-/, $coords;

    my $dir = $base_work_dir . $gene;
    my $params = [
        '--target-start'  => $start,
        '--target-end'    => $end,
        '--chromosome'    => $chr,
        '--target-gene'   => $gene,
        '--dir'           => $dir,
        '--strand'        => 1,
        '--num-oligos'    => 3,
        '--design-method' => 'deletion',
    ];

    return ( $params, $dir );
}
