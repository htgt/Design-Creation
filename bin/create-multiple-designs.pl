#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use IPC::System::Simple qw( system );
use Text::CSV;
use Try::Tiny;
use Getopt::Long;
use List::MoreUtils qw( any );
use Pod::Usage;

my ( $file, $persist, $base_work_dir );
GetOptions(
    'help'        => sub { pod2usage( -verbose => 1 ) },
    'man'         => sub { pod2usage( -verbose => 2 ) },
    'file=s'      => \$file,
    'persist'     => \$persist,
    'dir=s'       => \$base_work_dir,
    'conditional' => \my $conditional,
    'debug'       => \my $debug,
    'gene=s'      => \my @genes,
    'param=s'     => \my %extra_params,
) or pod2usage(2);

die( 'Specify base work dir' ) unless $base_work_dir;
die( 'Specify file with design info' ) unless $file;

open ( my $fh, '<', $file ) or die( "Can not open $file " . $! );
my $csv = Text::CSV->new();
$csv->column_names( @{ $csv->getline( $fh ) } );

while ( my $data = $csv->getline_hr( $fh ) ) {
    process_design( $data );
}

close $fh;

sub process_design {
    my $data = shift;

    if ( @genes ) {
        return unless any { $data->{'target-gene'} eq $_ } @genes;
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

    return;
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

__END__

=head1 NAME

create-multiple-designs.pl - Create multiple designs

=head1 SYNOPSIS

  create-multiple-designs.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Print debug messages
      --file            File with design details.
      --persist         Persist newly created designs to LIMS2
      --dir             Directory where design-create output goes
      --conditional     Specify conditional design, default deletion
      --gene            Only create this gene(s), picked from input file
      --param           Specify additional param(s) not in file

=head1 DESCRIPTION

Takes design information for multiple designs from file and tries to create these designs.

The file will be a csv file, each row represents a design, each column a parameter given to the
design create command. The column headers represent the parameter name.

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
