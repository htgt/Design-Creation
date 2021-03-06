#!/bin/bash
PROGRAMPATH=/nfs/team87/farm3_lims2_vms/software/perl/bin

BASE_DIR=/lustre/scratch117/sciops/team87/design-create

WORK_DIR=$BASE_DIR/designs_workdir/$LSB_JOBINDEX

# create base work dir for job index if it does not exist
mkdir -p $WORK_DIR || exit 1

INPUT_FILE=$BASE_DIR/input/$LSB_JOBINDEX

$PROGRAMPATH/create-multiple-designs.pl --debug --persist --file $INPUT_FILE --dir $WORK_DIR

exit $?

# SETUP
# source /nfs/team87/farm3_lims2_vms/conf/run_in_farm3 [wge|wge_devel|lims2_live|lims2_staging|path to custom rest client config]
# example bsub:
# bsub -J"create-designs[1-10]%3" -G team87-grp -q long -R"select[mem>2500] rusage[mem=2500] span[hosts=1]" -M2500 -n2 -o output/create-designs.%J-%I -e error/create-designs.%J-%I farm-wrapper-script.sh 
