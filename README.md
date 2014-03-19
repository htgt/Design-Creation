DESIGN-CREATION
===============

Create a Knock-Out design for a given target.

Overview:

1. Specify target region for design.
2. Determine the coordinates of the regions the oligos will be found in.
3. Produce list of possible oligos/primers, using Primer3 or AOS.
4. Filter and rank oligos, pick the best one of each type.
5. Consolidate Design Data
6. Persist design with oligos to LIMS2 or WGE.

* * *

INPUT DATA
==========

Design Parameters:
------------------
* target coordinates
    * species
    * genome / assembly
    * chromosome name
    * chromosome strand
    * chromosome coordiantes
OR
* target gene
    * species
    * genomes / assembly
    * start exon
    * end exon
PLUS
* design type
* name

Oligo Profile:
--------------
* defined regions oligos must be located in based on type of design

### Conditional Ready Gibson Design ( +ve Stranded )

```
|--five prime region--|------exon region-------|--three prime region-|

   5F              5R   EF      TARGET      ER   3F              3R
|======|---------|====|====|-|   >>>>   |-|====|====|---------|======|
|------|                                                                   > 5F Region Length
       |---------|                                                         > 5F Region Offset
                 |---------|                                               > 5R-EF Region Length
                           |-|                                             > 5R-EF Region Offset
                                        |-|                                > ER-3F Region Offset
                                          |---------|                      > ER-3F Region Length
                                                    |---------|            > 3R Region Offset
                                                              |------|     > 3R Region Length
```

### Conditional Ready Gibson Design ( -ve Stranded )

```
|--three prime region-|------exon region-------|--five prime region--|

   3R              3F   ER      TARGET      EF   5R              5F
|======|---------|====|====|-|   <<<<   |-|====|====|---------|======|
|------|                                                                   > 3R Region Length
       |---------|                                                         > 3R Region Offset
                 |---------|                                               > 3F-ER Region Length
                           |-|                                             > 3F-ER Region Offset
                                        |-|                                > EF-5R Region Offset
                                          |---------|                      > EF-5R Region Length
                                                    |---------|            > 5F Region Offset
                                                              |------|     > 5F Region Length
```

### Deletion Gibson Design ( +ve Stranded )

```
|--five prime region--|------exon region-------|--three prime region-|

   5F                   5R      TARGET      3F                   3R
|======|--------------|====|-|   >>>>   |-|====|--------------|======|
|------|                                                                   > 5F Region Length
       |--------------|                                                    > 5F Region Offset
                      |----|                                               > 5R Region Length
                           |-|                                             > 5R Region Offset
                                        |-|                                > 3F Region Offset
                                          |----|                           > 3F Region Length
                                               |--------------|            > 3R Region Offset
                                                              |------|     > 3R Region Length
```

### Conditional Ready Gibson Design ( -ve Stranded )

```
|--three prime region-|------exon region-------|--five prime region--|

   3R                   3F      TARGET      5R                   5F
|======|--------------|====|-|   <<<<   |-|====|--------------|======|
|------|                                                                   > 3R Region Length
       |--------------|                                                    > 3R Region Offset
                      |----|                                               > 3F Region Length
                           |-|                                             > 3F Region Offset
                                        |-|                                > 5R Region Offset
                                          |----|                           > 5R Region Length
                                               |     ---------|            > 5F Region Offset
                                                              |------|     > 5F Region Length
```

### Conventional Deletion / Insertion

```
   G5               U5       TARGET       D3               G3
|======|---------|======|-|          |-|======|---------|======|
|------|                                                           > G5 Region Length
       |------------------|                                        > G5 Region Offset
                 |------|                                          > U5 Region Length
                        |-|                                        > U5 Region Offset
                                       |------|                    > D3 Region Length
                                     |-|                           > D3 Region Offset
                                                        |------|   > G3 Region Length
                                     |------------------|          > G3 Region Offset
```

### Conventional Conditional

```
   G5              U-REGION           D-REGION             G3
|======|---------|==========|-------|==========|--------|======|
|------|                                                           > G5 Region Length
       |---------|                                                 > G5 Region Offset
                      |-|                                          > U Oligo Min Gap
                                         |-|                       > D Oligo Min Gap
                                                        |------|   > G3 Region Length
                                             |-----------------|   > G3 Region Offset
```


* * *

WORKFLOW
========

1: Specify Target Area
======================
Specify a targetion region for the design, you can either target a specific set of exons on
a gene or a custom location on the genome.
This step outputs a yaml file with a set of coordinates for the target region.

### Exon Target Input:
* target gene
* start exon
* end exon
* species
* assembly

### Custom Target Input:
* target gene
* chromosome name
* strand
* start coordinate
* end coordinate
* species
* assembly

* * *

2: Oligo Target Regions
=======================
Given the target coordinates for the design plus the parameters for the oligos
produce oligo target region coordinate files.

See diagrams above for details of what parameters used to specify oligo regions.

The gibson designs use Primer3 to find pairs of oligos for each region.
The recombinering designs use AOS, which finds single oligos in a given region.

###input:
* design params
    * design coordinates
        * chromosome
        * strand
        * start
        * end
    * species
    * assembly
* oligo profile ( see diagrams above )

###output: coordinates for target region of each oligo
* Recombinering design
    * G5 region
    * U5 region
    * U3 region ( optional )
    * D5 region ( optional )
    * D3 region
    * G3 region
* Gibson Design
    * 5' region
    * Exon region ( optional )
    * 3' region

* * *

3: Produce Oligos
=================
Run Primer3 or AOS to find potential oligos for design.

Primer3 Wrapper
---------------

TODO

AOS Wrapper
-----------
There is a step before AOS runs that takes the oligo target region coordinates file produced
in the previous step and makes files with the sequence of these oligo regions.

The wrapper takes target sequence and outputs a list of primers for that region.
Need to wrap up input and output for aos to produce usable output for next step.

To work out assembly coordinates we use the offset information returned by aos for each oligo.
This information plus the oligo target region coordinates is enough to work out
the assembly coordinates for the oligos.

###input:
* query sequence file
* target sequence file ( currently chr file )
* AOS parameters
    * oligo length ( 50 )
    * minimum GC content ( 28 )
    * number oligos ( 3 )
    * mask by lower-case? ( no )
    * genomic search method ( blat )

###output:
* list of oligos, with following details:
    * sequence
    * assembly coordinates
    * id

* * *

4: Oligo Filtering
==================
We will have multiple oligos of each type, need to filter out bad ones.
Both Primer3 and AOS return oligos ranked from best to worst, we want to pick
the best ranked oligos of each type that also pass our validation steps.

###input:
* oligos
* design type

###output:
* validated oligo for each oligo type
* throw error if we can't find given oligo type

Oligo Validity
--------------
Check following:
* Coordinates for oligo are worked out correctly
* Length of oligo is correct
* Sequence is the same as the sequence from ensembl for given coordinates

Oligo Specificity
-----------------
* Gibson designs: use bwa to check oligo specificity in genome.
* Recombinering designs: check specificity inside bac
    * use genomes flanking sequence, 100k by default, to represent bac sequence.
    * uses exonerate to do the alignment.

* * *

4a: Find Valid U/D Region Oligo Pairs ( conditional recombinering designs only )
=====================================
The pair of oligos from the U and D regions of conditional designs were produced
by splitting the respective regions in two and getting the appropriate oligo from each half.

We must find the best pairs of U and D oligos that fit the gap criteria for those oligos.
They may have a minimum gap distance between the oligos, and a optional maximum gap distance too.

The closer the oligos are to the minimum gap distance the better.

###input:
* U5 and U3 oligos
* D5 and D3 oligos
* U Oligo Min Gap
* U Oligo Max Gap ( optional )
* D Oligo Min Gap
* D Oligo Max Gap ( optional )

###output
* Best pair of U5 and U3 oligos
* Best pair of D5 and D3 oligos

* * *

4b: Find Best Gap Oligo Pair ( recombinering designs only )
============================
We need to carry out additional checks on the G5 and G3 oligos and then
find the best pair of oligos to use.

All the oligo sequences and tiled into sections of sequence 6 bases long and then
compared against each other. If a pair of oligos has any matching 6 base sequences
then it is not a good oligo pair.

###input:
* G5 and G3 oligos

###output
* Best pair of G5 and G3 oligos

* * *

5: Consolidate Design Data
==========================
Create the yaml design file, that will be used in the next persist step.
Brings together all the data from the previous steps and formats it correctly.
Also calls seperate module to work out phase of design.

###input:
* target name
* species
* design type
* oligos
    * type
    * sequence
    * loci
        * assembly
        * chr name
        * start
        * end
* created by

###output
* design data yaml file

Design Phase
------------
To work our the phase the target transcript and oligo coordinates are required.

* * *

6: Persist Design
=================
Once we have valid oligos for the target we persist it, to LIMS2 or WGE.
Use the LIMS2 / WGE api to insert design.

###input:
* design data yaml file

###output:
* design stored in LIMS2 or WGE
