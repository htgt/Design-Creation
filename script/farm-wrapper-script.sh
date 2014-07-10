#!/bin/bash

PROGRAMPATH=~/workspace/Design-Creation/bin

BASE_DIR=/lustre/scratch109/sanger/sp12/design-create

WORK_DIR=$BASE_DIR/designs_workdir/$LSB_JOBINDEX

# create base work dir for job index if it does not exist
mkdir -p $WORK_DIR || exit 1

INPUT_FILE=$BASE_DIR/input/$LSB_JOBINDEX

$PROGRAMPATH/create-multiple-designs.pl --debug --persist --gibson-del-exon --file $INPUT_FILE --dir $WORK_DIR

exit $?

#split -a1 -d -l 380 designs.txt input/

# source /nfs/team87/farm3_lims2_vms/conf/run_in_farm3 lims2_live 
#bsub -J"create-designs[1-10]%3" -G team87-grp -q long -R"select[mem>2500] rusage[mem=2500] span[hosts=1]" -M2500 -n2 -o output/create-designs.%J-%I -e error/create-designs.%J-%I ~/workspace/Design-Creation/bin/farm-wrapper-script.sh
