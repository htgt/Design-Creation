#!/bin/bash

PROGRAMPATH=~/workspace/Design-Creation/bin

BASE_DIR=/lustre/scratch109/sanger/sp12/design-create

WORK_DIR=$BASE_DIR/human_designs/$LSB_JOBINDEX

# create base work dir for job index if it does not exist
mkdir -p $WORK_DIR || exit 1

INPUT_FILE=$BASE_DIR/input/$LSB_JOBINDEX

$PROGRAMPATH/create-multiple-designs.pl --debug --persist --del-exon --alt-designs --file $INPUT_FILE --dir $WORK_DIR

exit $?

#split -a1 -d -l 380 designs.txt input/
#~/workspace/LIMS2-WebApp/script/run_in_perlbrew 'bsub -J"create-designs[1-10]%3" -P team87-grp -q long -R"select[mem>800] rusage[mem=800]" -M800000 -o output/create-designs.%J-%I -e error/create-designs.%J-%I ~/workspace/Design-Creation/bin/farm-wrapper-script.sh'
