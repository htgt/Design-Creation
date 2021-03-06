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

#'region-offset-5r-ef' ,
#'region-offset-er-3f',
const my @DESIGN_COLUMN_HEADERS => (
'cmd',
'target-gene',
'target-exon',
'exon-check-flank-length',
'species',
'repeat-mask-class',
'region-offset-5r' ,
'region-length-5r' ,
'region-offset-5f',
'region-length-5f',
'region-offset-3f',
'region-length-3f',
'region-offset-3r',
'region-length-3r',
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
my $current_exon = '';
for my $line ( @log_data ) {
    if ( $line =~ /Exon\stargets:\s(.*)$/  ) {
        $current_exon = $1;
    }
    if ( $line =~ /ERROR\s(\S*)\sDESIGN\sINCOMPLETE:\s(.*)$/  ) {
        my $gene = $1;
        my $error_reason = $2;
        push @{ $failed_genes{ $gene } }, { exon_id => $current_exon, error => $error_reason };
    }
}

#
# find design targets and current designs for failed gene targets
#
#my @design_targets = $schema->resultset('DesignTarget')->search(
    #{
        #species_id => $species,
        #gene_id    => { 'IN' => [ keys %failed_genes ] },
        #build_id   => $DEFAULT_BUILD,
    #}
#);
#my %sorted_dts;
#for my $dt ( @design_targets ) {
    #push @{ $sorted_dts{ $dt->gene_id } }, $dt;
#}

#my ( $design_data ) = bulk_designs_for_design_targets( $schema, \@design_targets, $species, $DEFAULT_ASSEMBLY );

#
# Loop through failed genes / exons and output new design parameters if needed
#
#TODO add exon length sp12 Wed 15 Jan 2014 13:16:33 GMT
for my $gene_id ( keys %failed_genes ) {
    # if a gene already has 'enough' designs then skip its other failed targets
    #next if enough_designs( $gene_id, $sorted_dts{ $gene_id } );

    for my $datum ( @{ $failed_genes{ $gene_id } } ) {
        my $fail_reason = $datum->{error};
        my $exon = $datum->{exon_id};
        my %params = %{ $design_params{ $exon } };
        $params{comment} = $fail_reason;
        next if $fail_reason =~ /Invalid chromosome name/;
        auto_param_adjust_deletion_gibson( \%params, $fail_reason );
        $target_output_csv->print( $target_output, [ @params{ @DESIGN_COLUMN_HEADERS } ] );
    }
}

# REMOVE - TEMP HACK
sub auto_param_adjust_deletion_gibson {
    my ( $params, $fail_reason ) = @_;

    $params->{'repeat-mask-class'} = 'trf|dust';
    if ( $fail_reason =~ /5F/ ) {
        $params->{'region-offset-5f'} = 1500;
        $params->{'region-length-5f'} = 1000;
    }

    if ( $fail_reason =~ /5R/ ) {
        $params->{'region-length-5r'} = 250;
    }

    if ( $fail_reason =~ /five_prime/ ) {
        $params->{'region-offset-5f'} = 1500;
        $params->{'region-length-5f'} = 1000;
        $params->{'region-length-5r'} = 250;
    }

    if ( $fail_reason =~ /3R/ ) {
        $params->{'region-offset-3r'} = 1500;
        $params->{'region-length-3r'} = 1000;
    }

    if ( $fail_reason =~ /3F/ ) {
        $params->{'region-length-3f'} = 250;
    }

    if ( $fail_reason =~ /three_prime/ ) {
        $params->{'region-offset-3r'} = 1500;
        $params->{'region-length-3r'} = 1000;
        $params->{'region-length-3f'} = 250;
    }

    return;
}

# does a gene already have enough designs
## no critic(ProhibitCascadingIfElse)
#sub enough_designs{
    #my ( $gene_id, $dts ) = @_;
    #my $dt_count = @{ $dts };

    #my $design_count = 0;
    #for my $dt ( @{ $dts } ) {
        #$design_count++ if @{ $design_data->{ $dt->id } };
    #}

    #INFO( "$gene_id: $dt_count design targets and $design_count designs" );
    ## if every design target has a design then we are good
    #if ( $design_count == $dt_count ) {
        #return 1;
    #}
    #elsif ( $design_count == 0 ) {
        #return;
    #}
    ## 4 / 5 targets and 2+ designs ok
    #elsif ( $dt_count > 3 && $design_count > 1 ) {
        #return 1;
    #}
    ## 1/2/3 targets and 1+ designs ok
    #elsif ( $dt_count <= 3 && $design_count >= 1 ){
        #return 1;
    #}
    #else {
        #return;
    #}
#}
## use critic

__END__

=head1 NAME

parse_failed_design_attempts.pl - create another design param file from failed designs on old multi design run

=head1 SYNOPSIS

  parse_failed_design_attempts.pl --log-files [file] --param-file [file] --species [Human|Mouse]

      --help            Display a brief help message
      --man             Display the manual page
      --log-file        Log file from previous create-multiple-designs.pl run
      --param-file      Parameter file from previous create-multiple-designs.pl run
      --species         Species of design targets

Only works for exon targets designs, not specific location target designs.

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
