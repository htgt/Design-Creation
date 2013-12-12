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
use LIMS2::Model::Util::DesignTargets qw( bulk_designs_for_design_targets );
use LIMS2::Model;
use feature qw( say );

GetOptions(
    'help'         => sub { pod2usage( -verbose => 1 ) },
    'man'          => sub { pod2usage( -verbose => 2 ) },
    'log-file=s'   => \my $log_file,
    'param-file=s' => \my $param_file,
    'species=s'    => \my $species,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $INFO, layout => '%p %m%n' } );
LOGDIE( 'Must specify species' ) unless $species;

my $schema = LIMS2::Model->new( user => 'webapp' )->schema;

const my $DEFAULT_BUILD => 73;
const my $DEFAULT_ASSEMBLY => $species eq 'Human' ? 'GRCh37' :  $species eq 'Mouse' ? 'GRCm38' : undef;

const my @DESIGN_COLUMN_HEADERS => (
'target-gene',
'target-exon',
'exon-check-flank-length',
'species',
'repeat-mask-class',
'region-offset-5r-ef' ,
'region-offset-5f',
'region-offset-er-3f',
'region-offset-3r',
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
    $design_params{ $data->{'target-exon'} } = $data;
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
        my $exon = $2;
        my $error_reason = $3;
        push @{ $failed_genes{ $gene } }, { exon_id => $exon, error => $error_reason };
    }
}

#
# find design targets and current designs for failed gene targets
#
my @design_targets = $schema->resultset('DesignTarget')->search(
    {
        species_id => $species,
        gene_id    => { 'IN' => [ keys %failed_genes ] },
        build_id   => $DEFAULT_BUILD,
    }
);
my %sorted_dts;
for my $dt ( @design_targets ) {
    push @{ $sorted_dts{ $dt->gene_id } }, $dt;
}

my ( $design_data ) = bulk_designs_for_design_targets( $schema, \@design_targets, $species, $DEFAULT_ASSEMBLY );

#
# Loop through failed genes / exons and output new design parameters if needed
#
for my $gene_id ( keys %failed_genes ) {
    # if a gene already has 'enough' designs then skip its other failed targets
    next if enough_designs( $gene_id, $sorted_dts{ $gene_id } );

    for my $datum ( @{ $failed_genes{ $gene_id } } ) {
        my $fail_reason = $datum->{error};
        my $exon = $datum->{exon_id};
        my %params = %{ $design_params{ $exon } };
        $params{comment} = $fail_reason;
        $target_output_csv->print( $target_output, [ @params{ @DESIGN_COLUMN_HEADERS } ] );
    }
}

# does a gene already have enough designs
## no critic(ProhibitCascadingIfElse)
sub enough_designs{
    my ( $gene_id, $dts ) = @_;
    my $dt_count = @{ $dts };

    my $design_count = 0;
    for my $dt ( @{ $dts } ) {
        $design_count++ if @{ $design_data->{ $dt->id } };
    }

    INFO( "$gene_id: $dt_count design targets and $design_count designs" );
    # if every design target has a design then we are good
    if ( $design_count == $dt_count ) {
        return 1;
    }
    elsif ( $design_count == 0 ) {
        return;
    }
    # 4 / 5 targets and 2+ designs ok
    elsif ( $dt_count > 3 && $design_count > 1 ) {
        return 1;
    }
    # 1/2/3 targets and 1+ designs ok
    elsif ( $dt_count <= 3 && $design_count >= 1 ){
        return 1;
    }
    else {
        return;
    }
}
## use critic

__END__

=head1 NAME

temp_parse_output.pl - create another design param file from failed designs on old multi design run

=head1 SYNOPSIS

  temp_parse_output.pl --log-files [file] --param-file [file] --species [Human|Mouse] 

      --help            Display a brief help message
      --man             Display the manual page
      --log-file        Log file from previous create-multiple-designs.pl run 
      --param-file      Parameter file from previous create-multiple-designs.pl run
      --species         Species of design targets 

=head1 DESCRIPTION

This script will parse the output log file and find the failed designs plus the reason it failed.
Then it will output a new design parameters file for all the failed designs ( along with reason for fail )
It will skip a failed design if the gene that is targeted already has enough designs on other targets.

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
