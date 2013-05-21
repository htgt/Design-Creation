#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

#
# Temp report: lists designs we have for given gene exon targets
# Expects csv file with 3 columns of data:
# target-gene: HGNC gene symbol
# target-exon: EnsEMBL exon id
# ensembl-gene: EnsEMBL gene id
#

use Text::CSV;
use Try::Tiny;
use LIMS2::Model;
use LIMS2::Util::EnsEMBL;
use Getopt::Long;
use List::MoreUtils qw( any );
use IO::Handle;
use Log::Log4perl ':easy';
use Const::Fast;

my $log_level = $WARN;
GetOptions(
    'debug'   => sub { $log_level = $DEBUG },
    'verbose' => sub { $log_level = $INFO },
    'trace'   => sub { $log_level = $TRACE },
    'file=s'  => \my $file,
);

const my @COLUMN_HEADERS => (
'target-gene',
'ensembl-gene',
'target-exon',
'exon-size',
'exon-rank',
'num-designs',
'no-designs-for-gene',
);

die( 'Must specify input file' ) unless $file;
my $model = LIMS2::Model->new( user => 'webapp', audit_user => $ENV{USER}.'@sanger.ac.uk' );
my $ensembl_util = LIMS2::Util::EnsEMBL->new( species => 'Human' );
Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );

my $io_output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $output_csv = Text::CSV->new( { eol => "\n" } );
$output_csv->print( $io_output, \@COLUMN_HEADERS );

## no critic(InputOutput::RequireBriefOpen)
my $csv = Text::CSV->new();
open ( my $fh, '<', $file ) or die( "Can not open $file " . $! );
$csv->column_names( @{ $csv->getline( $fh ) } );

while ( my $data = $csv->getline_hr( $fh ) ) {
    Log::Log4perl::NDC->remove;
    Log::Log4perl::NDC->push( $data->{'target-gene'} );
    Log::Log4perl::NDC->push( $data->{'target-exon'} );
    process_design_target( $data );
}

close $fh;
## use critic

sub process_design_target {
    my $data = shift;
    DEBUG( 'Grabbing designs in LIMS that target gene' );

    my $designs_rs = $model->schema->resultset('Design')->search(
        {
            'genes.gene_id' => $data->{'target-gene'},
            species_id => 'Human',
        },
        {
            join => 'genes'
        }
    );
    my $design_count = $designs_rs->count;
    unless ( $design_count ) {
        ERROR( 'Found no designs for target gene' );
        print_target_report( $data, [], 'yes');
        return;
    }
    INFO( "Found $design_count designs for gene" );

    my $designs_for_exon = find_design_for_target_exon( $designs_rs, $data->{'target-exon'} );
    my $design_exon_count = scalar( @{ $designs_for_exon } );
    INFO( "Found $design_exon_count designs for exon" );
    print_target_report( $data, $designs_for_exon );

    return;
}

sub find_design_for_target_exon {
    my ( $designs_rs, $target_exon_name ) = @_;
    my @designs_for_exon;

    while ( my $design = $designs_rs->next ) {
        my @floxed_exons;

        try{
            @floxed_exons = @{ $design->info->floxed_exons } };
        catch {
            ERROR( 'Can not get floxed exons for design ' . $design->id );
        };

        unless( @floxed_exons ) {
            ERROR('No floxed exons');
            next;
        }
        if ( any { $target_exon_name eq $_->stable_id } @floxed_exons ) {
            push @designs_for_exon, $design->id;
        }
    }

    return \@designs_for_exon;
}

sub print_target_report {
    my ( $data, $designs_for_exon, $no_designs_for_gene ) = @_;
    my %design_params;

    my $target_exon = $ensembl_util->exon_adaptor->fetch_by_stable_id( $data->{'target-exon'} );
    my $gene = $ensembl_util->gene_adaptor->fetch_by_stable_id( $data->{'ensembl-gene'} );
    my $exon_rank = try{ get_exon_rank( $target_exon, $gene ) };

    $design_params{'target-gene'} = $data->{'target-gene'};
    $design_params{'target-exon'} = $data->{'target-exon'};
    $design_params{'ensembl-gene'} = $data->{'ensembl-gene'};
    $design_params{'exon-size'} = $target_exon ? $target_exon->length : '-';
    $design_params{'exon-rank'} = $exon_rank;
    $design_params{'num-designs'} = scalar( @{ $designs_for_exon } );
    $design_params{'no-designs-for-gene'} = $no_designs_for_gene;

    $output_csv->print( $io_output, [ @design_params{ @COLUMN_HEADERS } ] );

    return;
}

sub get_exon_rank {
    my ( $exon, $gene ) = @_;

    my $canonical_transcript = $gene->canonical_transcript;
    INFO( 'Canonical transcript: ' . $canonical_transcript->stable_id );

    my $rank = 1;
    for my $current_exon ( @{ $canonical_transcript->get_all_Exons } ) {
        return $rank if $current_exon->stable_id eq $exon->stable_id;
        $rank++;
    }

    return 0;
}
