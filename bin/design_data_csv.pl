#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl ':easy';
use Pod::Usage;
use Path::Class qw( dir );
use YAML::Any qw( LoadFile DumpFile );
use Hash::MoreUtils qw( slice_def );
use Const::Fast;
use Text::CSV;
use IO::Handle;
use Try::Tiny;
use Bio::Perl;

const my @COLUMN_HEADERS => qw(
target_gene
target_exon
chr_name
chr_strand
5F
5R
EF
ER
3F
3R
);

my $log_level = $WARN;
GetOptions(
    'help'          => sub { pod2usage( -verbose => 1 ) },
    'man'           => sub { pod2usage( -verbose => 2 ) },
    'debug'         => sub { $log_level = $DEBUG },
    'verbose'       => sub { $log_level = $INFO },
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );

my $io_output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $io_output, \@COLUMN_HEADERS );

for my $dir_name ( @ARGV ) {
    my $dir = dir( $dir_name );
    INFO( "Working on $dir directory" );

    my $design_params = LoadFile( $dir->file( 'design_parameters.yaml' ) );
    my $design = try{ LoadFile( $dir->file( 'design_data.yaml' ) ) };

    unless ( $design ) {
        ERROR( "No design data file in folder $dir" );
        next;
    }

    my %params = slice_def( $design_params, qw( chr_name chr_strand target_exon ) );
    $params{target_gene} = @{ $design_params->{target_genes} }[0];

    my %data = ( %{ parse_oligo_data( $design->{oligos}, $params{chr_strand} ) }, %params );
    $output_csv->print( $io_output, [ @data{ @COLUMN_HEADERS } ] );
}

sub parse_oligo_data {
    my ( $oligos, $strand ) = @_;
    my %oligo_data;

    for my $oligo ( @{ $oligos } ) {
        $oligo_data{ $oligo->{type} } = _seq_comp( $oligo, $strand );
    }

    return \%oligo_data;
}

# revcomp oligo seq where appropriate
sub _seq_comp {
    my ( $oligo, $strand ) = @_;
    my $type = $oligo->{type};
    my $seq = $oligo->{seq};

    if ( $type =~ /F$/ ) {
        return $strand == 1 ? $seq : revcom( $seq )->seq;
    }
    elsif ( $type =~ /R$/ ) {
        return $strand == 1 ? revcom( $seq )->seq : $seq;
    }
    else {
        LOGDIE( "Unknown oligo type $type" );
    }

    return;
}

__END__

=head1 NAME

design_yaml_to_csv.pl - Grab data from design output and show as csv

=head1 SYNOPSIS

  design_yaml_to_csv.pl [options] [design directories]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output

=head1 DESCRIPTION

Input a list of design directories, parse information in design_data.yaml and
design_parameters.yaml and output a csv file with oligo seq and some other information.

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
