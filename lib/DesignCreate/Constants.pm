package DesignCreate::Constants;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Constants::VERSION = '0.010';
}
## use critic

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
    $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME
    $DEFAULT_AOS_WORK_DIR_NAME
    $DEFAULT_GAP_OLIGO_LOG_DIR_NAME

    $DEFAULT_OLIGO_COORD_FILE_NAME
    $DEFAULT_DESIGN_DATA_FILE_NAME
    $DEFAULT_ALT_DESIGN_DATA_FILE_NAME
    $DEFAULT_PRIMER3_CONFIG_FILE

    $DEFAULT_AOS_LOCATION
    %CURRENT_ASSEMBLY
    %GIBSON_PRIMER_REGIONS
    %DEFAULT_CHROMOSOME_DIR
    );
    our %EXPORT_TAGS = ();
}

const our $DEFAULT_VALIDATED_OLIGO_DIR_NAME      => 'validated_oligos';
const our $DEFAULT_OLIGO_FINDER_OUTPUT_DIR_NAME  => 'oligo_finder_output';
const our $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME => 'oligo_target_regions';
const our $DEFAULT_EXONERATE_OLIGO_DIR_NAME      => 'exonerate_oligos';
const our $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME      => 'block_oligo_logs';
const our $DEFAULT_AOS_WORK_DIR_NAME             => 'aos_work';
const our $DEFAULT_GAP_OLIGO_LOG_DIR_NAME        => 'gap_oligo_logs';

const our $DEFAULT_OLIGO_COORD_FILE_NAME     => 'oligo_region_coords.yaml';
const our $DEFAULT_DESIGN_DATA_FILE_NAME     => 'design_data.yaml';
const our $DEFAULT_ALT_DESIGN_DATA_FILE_NAME => 'alt_designs.yaml';
#TODO move this sp12 Mon 05 Aug 2013 09:23:31 BST
const our $DEFAULT_PRIMER3_CONFIG_FILE       =>
    '/nfs/users/nfs_s/sp12/workspace/Design-Creation/tmp/primer3/primer3_config.yaml';

#TODO change default location sp12 Mon 05 Aug 2013 09:02:36 BST
const our $DEFAULT_AOS_LOCATION => $ENV{AOS_LOCATION}
    || '/nfs/users/nfs_s/sp12/workspace/ArrayOligoSelector';

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
