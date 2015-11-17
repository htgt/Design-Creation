#!/usr/bin/env perl -d
use strict;
use warnings FATAL => 'all';

use IPC::System::Simple qw( system );
use Text::CSV;
use Try::Tiny;
use Getopt::Long;
use Path::Class;
use List::MoreUtils qw( any );
use Pod::Usage;
use feature qw( say );

my ( $file, $persist, $base_dir_name, $alt_designs );
GetOptions(
    'help'            => sub { pod2usage( -verbose => 1 ) },
    'man'             => sub { pod2usage( -verbose => 2 ) },
    'file=s'          => \$file,
    'persist'         => \$persist,
    'alt-designs'     => \$alt_designs,
    'dir=s'           => \$base_dir_name,
    'debug'           => \my $debug,
    'gene=s'          => \my @genes,
    'param=s'         => \my %extra_params,
    'dry-run'         => \my $dry_run,
) or pod2usage(2);

die( 'Specify base work dir' ) unless $base_dir_name;
die( 'Specify file with design info' ) unless $file;

my %targeted_genes;
my $base_dir = dir( $base_dir_name );
$base_dir = $base_dir->absolute;

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

    my ( $params, $design_cmd ) = get_params( $data );

    my @args;
    push @args, $debug ? '--debug' : '--verbose';
    push @args, '--alt-designs' if $alt_designs;
    push @args, '--persist' if $persist;

    for my $param_name ( keys %{ $params } ) {
        my @values = @{ $params->{$param_name} };
        for my $value ( @values ) {
            push @args, '--' . $param_name;
            push @args, $value;
        }
    }

    if ( %extra_params ) {
        while ( my( $cmd, $arg ) = each %extra_params ) {
            push @args, '--' . $cmd,;
            push @args, $arg;
        }
    }

    try{
        if ( $dry_run ) {
            say 'design-create ' . "$design_cmd " , join( ' ', @args );
        }
        else {
            system( 'design-create', $design_cmd, @args );
        }
    }
    catch{
        print $_;
    };

    return;
}

sub get_params {
    my ( $data ) = @_;

    my %params;
    my $design_cmd;
    while ( my( $cmd, $arg ) = each %{ $data } ) {
        next unless $arg;
        next unless $cmd;
        if ( $cmd eq 'cmd' ) {
            $design_cmd = $arg;
            next;
        }
        next if $cmd eq 'comment';
        # if multiple args we need to split it
        my @args = map{ _trim($_) } split /\|/, $arg;
        $params{ _trim($cmd) } = \@args;
    }

    unless ( $design_cmd ) {
        say 'NO cmd value, skipping record';
        return;
    }

    my $target_gene;
    if ( $design_cmd eq 'shorten-arm-design' ) {
        $target_gene = $data->{'design-id'};
    }
    else {
        $target_gene = _trim( $data->{'target-gene'} );
    }

    # can not have : symbols in dir name
    $target_gene =~ s/://g;

    my $dir_name;
    if ( exists $data->{'target-exon'} ) {
        my $target_exon = _trim($data->{'target-exon'});
        $target_exon =~ s/://g;
        $dir_name = $target_gene . '#' . $target_exon;
    }
    else {
        $dir_name = $target_gene . '-' . ++$targeted_genes{$target_gene}
    }

    my $dir = $base_dir->subdir($dir_name);
    $params{dir} = [ $dir->stringify ];
    return ( \%params, $design_cmd );
}

sub _trim{
    my $v = shift;
    $v =~ s/^\s+|\s+$//g;

    return $v;
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
      --alt-designs     Create alternate designs
      --dir             Directory where design-create output goes
      --gene            Only create this gene(s), picked from input file
      --param           Specify additional param(s) not in file
      --dry-run         Just print out command that would be called, don't call it
      --param           Specify additional parameter(s) to send to design creation program

=head1 DESCRIPTION

Takes design information for multiple designs from file and tries to create these designs.

The file will be a csv file, each row represents a design, each column a parameter given to the
design create command. The column headers represent the parameter name.

=head1 AUTHOR

Sajith Perera

=cut
