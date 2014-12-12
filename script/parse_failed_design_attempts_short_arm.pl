#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl ':easy';
use Pod::Usage;
use Perl6::Slurp;
use Text::CSV;
use IO::Handle;
use Const::Fast;

GetOptions(
    'help'         => sub { pod2usage( -verbose => 1 ) },
    'man'          => sub { pod2usage( -verbose => 2 ) },
    'log-file=s'   => \my $log_file,
    'param-file=s' => \my $param_file,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $INFO, layout => '%p %m%n' } );

const my @DESIGN_COLUMN_HEADERS => (
'cmd',
'target-gene',
'design-id',
'repeat-mask-class',
'region-offset-g5' ,
'region-length-g5' ,
'region-offset-g3',
'region-length-g3',
'design-comment',
'comment',
);

#
# store design parameters
#
open ( my $fh, '<', $param_file ) or die( "Can not open $param_file " . $! );
my $csv = Text::CSV->new();
$csv->column_names( @{ $csv->getline( $fh ) } );

my %design_params;
while ( my $data = $csv->getline_hr( $fh ) ) {
    $design_params{ $data->{'design-id'} } = $data;
}
close $fh;

#
# create new design parameter file
#
my $target_output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $target_output_csv = Text::CSV->new( { eol => "\n" } );
$target_output_csv->print( $target_output, \@DESIGN_COLUMN_HEADERS );

#
# parse log file for failed designs
#
my @log_data = slurp $log_file;
chomp( @log_data );
my %failed_genes;
for my $line ( @log_data ) {
    if ( $line =~ /ERROR\s(\S*)\s(\S*)\sDESIGN\sINCOMPLETE:\s(.*)$/  ) {
        my $gene = $1;
        my $design_id = $2;
        my $error_reason = $3;
        push @{ $failed_genes{$design_id} },
            { design_id => $design_id, error => $error_reason, gene => $gene };
    }
}

#
# Loop through failed genes / exons and output new design parameters if needed
#
for my $design_id ( keys %failed_genes ) {
    for my $datum ( @{ $failed_genes{ $design_id } } ) {
        my $fail_reason = $datum->{error};
        my %params = %{ $design_params{ $design_id } };
        $params{comment} = $fail_reason;
        next if $fail_reason =~ /Invalid chromosome name/;
        $target_output_csv->print( $target_output, [ @params{ @DESIGN_COLUMN_HEADERS } ] );
    }
}

__END__

=head1 NAME

parse_failed_design_attempts_short_arm.pl - create another design param file from failed short arm designs on old multi design run

=head1 SYNOPSIS

  parse_failed_design_attempts_short_arm.pl --log-files [file] --param-file [file]

      --help            Display a brief help message
      --man             Display the manual page
      --log-file        Log file from previous create-multiple-designs.pl run 
      --param-file      Parameter file from previous create-multiple-designs.pl run

=head1 DESCRIPTION

This script will parse the output log file and find the failed short arm designs plus the reason it failed.
Then it will output a new design parameters file for all the failed designs ( along with reason for fail )
It will skip a failed design if the gene that is targeted already has enough designs on other targets.

=head1 AUTHOR

Sajith Perera

=cut
