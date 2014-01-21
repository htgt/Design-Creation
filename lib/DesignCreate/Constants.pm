package DesignCreate::Constants;
use strict;
use warnings FATAL => 'all';

use base 'Exporter';
use Const::Fast;

BEGIN {
    our @EXPORT_OK = qw(
    $DEFAULT_VALIDATED_OLIGO_DIR_NAME
    $DEFAULT_OLIGO_FINDER_OUTPUT_DIR_NAME
    $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME
    $DEFAULT_EXONERATE_OLIGO_DIR_NAME
    $DEFAULT_BWA_OLIGO_DIR_NAME
    $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME
    $DEFAULT_AOS_WORK_DIR_NAME
    $DEFAULT_GAP_OLIGO_LOG_DIR_NAME

    $DEFAULT_OLIGO_COORD_FILE_NAME
    $DEFAULT_DESIGN_DATA_FILE_NAME
    $DEFAULT_ALT_DESIGN_DATA_FILE_NAME

    $PRIMER3_CONFIG_FILE
    $PRIMER3_CMD
    $AOS_LOCATION
    $BWA_CMD
    $SAMTOOLS_CMD
    $XA2MULTI_CMD
    $EXONERATE_CMD

    %CURRENT_ASSEMBLY
    %GIBSON_PRIMER_REGIONS
    %DEFAULT_CHROMOSOME_DIR
    %BWA_GENOME_FILES
    );
    our %EXPORT_TAGS = ();
}

const our $DEFAULT_VALIDATED_OLIGO_DIR_NAME      => 'validated_oligos';
const our $DEFAULT_OLIGO_FINDER_OUTPUT_DIR_NAME  => 'oligo_finder_output';
const our $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME => 'oligo_target_regions';
const our $DEFAULT_EXONERATE_OLIGO_DIR_NAME      => 'exonerate_oligos';
const our $DEFAULT_BWA_OLIGO_DIR_NAME            => 'bwa_oligos';
const our $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME      => 'block_oligo_logs';
const our $DEFAULT_AOS_WORK_DIR_NAME             => 'aos_work';
const our $DEFAULT_GAP_OLIGO_LOG_DIR_NAME        => 'gap_oligo_logs';

const our $DEFAULT_OLIGO_COORD_FILE_NAME     => 'oligo_region_coords.yaml';
const our $DEFAULT_DESIGN_DATA_FILE_NAME     => 'design_data.yaml';
const our $DEFAULT_ALT_DESIGN_DATA_FILE_NAME => 'alt_designs.yaml';

const our $PRIMER3_CONFIG_FILE => $ENV{PRIMER3_CONFIG}
    || '/nfs/team87/farm3_lims2_vms/conf/primer3_design_create_config.yaml';

const our $AOS_LOCATION => $ENV{AOS_LOCATION}
    || '/nfs/team87/farm3_lims2_vms/software/AOS';

const our $PRIMER3_CMD => $ENV{PRIMER3_CMD}
    || '/nfs/users/nfs_s/sp12/workspace/primer3-2.3.5/src/primer3_core';
#TODO switch to value below once vms upgraded sp12 Wed 11 Dec 2013 13:56:19 GMT
# '/nfs/team87/farm3_lims2_vms/software/primer3/src/primer3_core'

const our $BWA_CMD => $ENV{BWA_CMD}
    || '/software/solexa/bin/bwa';

const our $SAMTOOLS_CMD => $ENV{SAMTOOLS_CMD}
    || '/software/solexa/bin/samtools';

const our $XA2MULTI_CMD => $ENV{XA2MULTI_CMD}
    || '/software/solexa/bin/aligners/bwa/current/xa2multi.pl';

const our $EXONERATE_CMD => $ENV{EXONERATE_CMD}
    || '/software/team87/brave_new_world/app/exonerate-2.2.0-x86_64/bin/exonerate';
#TODO switch to value below once vms upgraded sp12 Wed 11 Dec 2013 13:58:43 GMT
# '/software/ensembl/exonerate-2.2.0/bin/exonerate'

const our %BWA_GENOME_FILES => (
    Human => '/lustre/scratch109/srpipe/references/Human/GRCh37_53/all/bwa/Homo_sapiens.GRCh37.dna.all.fa',
    Mouse => '/lustre/scratch109/srpipe/references/Mus_musculus/GRCm38/all/bwa/Mus_musculus.GRCm38.68.dna.toplevel.fa',
);

const our %CURRENT_ASSEMBLY => (
    Mouse => 'GRCm38',
    Human => 'GRCh37',
);

const our %GIBSON_PRIMER_REGIONS => (
    exon => {
        forward => 'EF',
        reverse => 'ER',
        slice  => 'exon_region_slice'
    },
    five_prime => {
        forward => '5F',
        reverse => '5R',
        slice  => 'five_prime_region_slice'
    },
    three_prime => {
        forward => '3F',
        reverse => '3R',
        slice  => 'three_prime_region_slice'
    },
);

const our %DEFAULT_CHROMOSOME_DIR => (
    Mouse => {
        GRCm38 => '/lustre/scratch110/blastdb/Users/team87/Mouse/GRCm38',
    },
    Human =>{
        GRCh37 => '/lustre/scratch110/blastdb/Users/team87/Human/GRCh37',
    },
);

1;

__END__
