#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use Text::CSV;
use Getopt::Long;
use LIMS2::Util::EnsEMBL;
use Log::Log4perl ':easy';
use IO::File;
use Pod::Usage;
use Const::Fast;
use LIMS2::Model;

my $log_level = $WARN;
GetOptions(
    'help'                 => sub { pod2usage( -verbose    => 1 ) },
    'man'                  => sub { pod2usage( -verbose    => 2 ) },
    'debug'                => sub { $log_level = $DEBUG },
    'verbose'              => sub { $log_level = $INFO },
    'trace'                => sub { $log_level = $TRACE },
    'species=s'            => \my $species,
    'old-assembly=s'       => \my $old_assembly,
    'new-assembly=s'       => \my $new_assembly,
    'new-build=s'          => \my $new_build,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );
LOGDIE( 'Must specify species' ) unless $species;
LOGDIE( 'Must specify old assembly' ) unless $old_assembly;
LOGDIE( 'Must specify new assembly' ) unless $new_assembly;
LOGDIE( 'Must specify new build' ) unless $new_build;

WARN( "ASSEMBLY: $new_assembly, BUILD: $new_build" );

my $model = LIMS2::Model->new( user => 'tasks' );

const my @TARGET_COLUMN_HEADERS => (
'gene_id',
'marker_symbol',
'ensembl_gene_id',
'ensembl_exon_id',
'exon_size',
'exon_rank',
'canonical_transcript',
'assembly',
'build',
'species',
'chr_name',
'chr_start',
'chr_end',
'chr_strand',
'automatically_picked',
'comment',
);

const my @FAILED_TARGETS_HEADERS => qw(
gene_id
marker_symbol
ensembl_exon_id
);

my $ensembl_util = LIMS2::Util::EnsEMBL->new( species => $species );
my $db = $ensembl_util->db_adaptor;
my $db_details = $db->to_hash;
WARN("Ensembl DB: " . $db_details->{'-DBNAME'});

my ( $target_output, $target_output_csv, $failed_output, $failed_output_csv );
$target_output = IO::File->new( 'target_parameters.csv' , 'w' );
$target_output_csv = Text::CSV->new( { eol => "\n" } );
$target_output_csv->print( $target_output, \@TARGET_COLUMN_HEADERS );

$failed_output = IO::File->new( 'failed_targets.csv' , 'w' );
$failed_output_csv = Text::CSV->new( { eol => "\n" } );
$failed_output_csv->print( $failed_output, \@FAILED_TARGETS_HEADERS );

my @failed_targets;

## no critic(InputOutput::RequireBriefOpen)
{
    my $manually_picked_targets = $model->schema->resultset( 'DesignTarget' )->search_rs(
        {
            species_id           => $species,
            automatically_picked => 0,
            assembly_id          => $old_assembly,
        }
    );

    while ( my $target = $manually_picked_targets->next ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $target->gene_id );
        Log::Log4perl::NDC->push( $target->marker_symbol );
        Log::Log4perl::NDC->push( $target->ensembl_exon_id );

        try{
            process_target( $target );
        }
        catch{
            ERROR('Problem processing target: ' . $_ );
            push @failed_targets, $target;
        };
    }

    for my $failed_target ( @failed_targets ) {
        $failed_output_csv->print(
            $failed_output,
            [   $failed_target->gene_id,
                $failed_target->marker_symbol,
                $failed_target->ensembl_exon_id,
            ]
        );
    }
}
## use critic

sub process_target {
    my $target = shift;

    my $gene = $ensembl_util->gene_adaptor->fetch_by_stable_id( $target->ensembl_gene_id );

    my $exon;
    unless ( $gene ) {
        ERROR( "Can not find ensembl gene: " . $target->ensembl_gene_id );
        $exon = $ensembl_util->exon_adaptor->fetch_by_stable_id( $target->ensembl_exon_id );
        if ( $exon ) {
            WARN( '... but found exon' );
        }
        push @failed_targets, $target;
        return;
    }
    $exon = $ensembl_util->exon_adaptor->fetch_by_stable_id( $target->ensembl_exon_id );
    unless ( $exon ) {
        ERROR( "Can not find ensembl exon" );
        $exon = match_exons( $gene, $target );
        unless( $exon ) {
            push @failed_targets, $target;
            return;
        }
    }

    my %target_params = (
        species              => $species,
        assembly             => $new_assembly,
        build                => $new_build,
        automatically_picked => 0,
    );

    my $canonical_transcript = $gene->canonical_transcript;
    my $exon_rank = get_exon_rank( $exon, $canonical_transcript );

    $target_params{ 'gene_id' }              = $target->gene_id;
    $target_params{ 'marker_symbol' }        = $target->marker_symbol;
    $target_params{ 'ensembl_gene_id' }      = $gene->stable_id;
    $target_params{ 'ensembl_exon_id' }      = $exon->stable_id;
    $target_params{ 'exon_size' }            = $exon->length;
    $target_params{ 'exon_rank' }            = $exon_rank;
    $target_params{ 'canonical_transcript' } = $canonical_transcript->stable_id;
    $target_params{ 'chr_name' }             = $exon->seq_region_name;
    $target_params{ 'chr_start' }            = $exon->seq_region_start;
    $target_params{ 'chr_end' }              = $exon->seq_region_end;
    $target_params{ 'chr_strand' }           = $exon->seq_region_strand;
    $target_params{ 'comment' }              = $target->comment;

    $target_output_csv->print( $target_output, [ @target_params{ @TARGET_COLUMN_HEADERS } ] );

    return;
}

sub match_exons {
    my ( $gene, $target ) = @_;

    my $canonical_transcript = $gene->canonical_transcript;
    my $target_rank = $target->exon_rank;
    unless ( $target_rank ) {
        WARN( 'Exon has no rank' );
        return;
    };

    my $rank = 1;
    my $match_exon;
    for my $current_exon ( @{ $canonical_transcript->get_all_Exons } ) {
        if ( $rank == $target_rank ) {
            $match_exon = $current_exon;
            last;
        }
        $rank++;
    }
    return unless $match_exon;

    if ( $match_exon->length == $target->exon_size ) {
        WARN( 'Exon ' . $match_exon->stable_id . ' has same rank and size, using this' );
        return $match_exon;
    }

    return;
}

=head2 get_exon_rank

Get rank of exon on canonical transcript

=cut
sub get_exon_rank {
    my ( $exon, $canonical_transcript ) = @_;

    my $rank = 1;
    for my $current_exon ( @{ $canonical_transcript->get_all_Exons } ) {
        return $rank if $current_exon->stable_id eq $exon->stable_id;
        $rank++;
    }

    return 0;
}

__END__

=head1 NAME

transfer_manually_picked_targets_between_assemblies.pl -

=head1 SYNOPSIS

  gibson_design_targets.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output
      --trace           Trace output
      --species         Species of targets
      --old-assembly    ID of old / previous assembly
      --new-assembly    ID of new assembly
      --new-build       ID or new build

=head1 DESCRIPTION

Searches design_targets table for species and old-assembly for manually picked targets.
Tries to transfer these targets into the new assembly.
Output is a csv file you must load into LIMS.
Failed transfers are put in a seperate file.

=head1 AUTHOR

Sajith Perera

=cut
