#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl ':easy';
use Const::Fast;
use LIMS2::Model;
use Perl6::Slurp;
use Const::Fast;
use IO::Handle;
use Text::CSV;
use LIMS2::Model::Util::DesignTargets qw( bulk_designs_for_design_targets );
use feature qw( say );

my $log_level = $DEBUG;
GetOptions(
    'species=s'        => \my $species,
    'gene_name_type=s' => \my $gene_name_type,
    'missing'          => \my $missing,
);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );
LOGDIE( 'Must specify species' ) unless $species;
LOGDIE( 'Must select gene name type ( marker_symbol, gene_id or ensembl_gene_id' ) unless $gene_name_type;

const my $DEFAULT_ASSEMBLY => $species eq 'Human' ? 'GRCh37' :  $species eq 'Mouse' ? 'GRCm38' : undef;
const my $DEFAULT_BUILD => 73;

WARN( "ASSEMBLY: $DEFAULT_ASSEMBLY, BUILD: $DEFAULT_BUILD" );

my $schema = LIMS2::Model->new( user => 'webapp' )->schema;

my @genes = map{ chomp; $_ } slurp \*STDIN;

my $base_params = {
    'exon-check-flank-length' => 100,
    'species' => $species,
};

const my @DESIGN_COLUMN_HEADERS => (
'target-gene',
'target-exon',
keys %{ $base_params }
);

my $design_output = IO::Handle->new_from_fd( \*STDOUT, 'w' );
my $design_output_csv = Text::CSV->new( { eol => "\n" } );
$design_output_csv->print( $design_output, \@DESIGN_COLUMN_HEADERS );

# grab all design targets for genes
my @design_targets = $schema->resultset('DesignTarget')->search(
    {
        species_id      => $species,
        $gene_name_type => { 'IN' => \@genes },
        build_id        => $DEFAULT_BUILD,
    }
);

my ( $design_data ) = bulk_designs_for_design_targets( $schema, \@design_targets, $species, $DEFAULT_ASSEMBLY );

my %sorted_dts;
for my $dt ( @design_targets ) {
    push @{ $sorted_dts{ $dt->$gene_name_type } }, $dt;
}

#TODO check if the gene has any designs already sp12 Mon 09 Dec 2013 15:09:55 GMT
for my $gene ( @genes ) {
    Log::Log4perl::NDC->remove;
    Log::Log4perl::NDC->push( $gene );

    # grab all design targets for this gene
    my @dts = @{ $sorted_dts{ $gene } } if $sorted_dts{ $gene }; 
    if ( @dts ) {
        Log::Log4perl::NDC->push( $dts[0]->gene_id );

        next if enough_designs( \@dts );

        for my $dt ( @dts ) {
            my @designs = @{ $design_data->{ $dt->id } };

            unless ( @designs ) {
                my %design_params = %{ $base_params };
                $design_params{'target-gene'} = $dt->gene_id;
                $design_params{'target-exon'} = $dt->ensembl_exon_id;

                $design_output_csv->print( $design_output, [ @design_params{ @DESIGN_COLUMN_HEADERS } ] );
            }
        }
    }
    else {
        WARN('No Targets');
        say "$gene,MISSING";
    }
}

sub enough_designs{
    my ( $dts ) = @_;
    my $dt_count = @{ $dts };

    my $design_count = 0;
    for my $dt ( @{ $dts } ) {
        $design_count++ if @{ $design_data->{ $dt->id } };
    }

    INFO( "$dt_count design targets and $design_count designs" );
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
