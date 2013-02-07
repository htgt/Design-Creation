DESIGN-CREATION
===============

Create a Knock-Out design for a given target.

Overview:

1. Specify target area(s) coordinates for design.
2. Produce oligo target ( candidate ) region sequences.
3. Produce list of possible oligos, using AOS.
4. Filter and rank oligos, pick the best one of each type.
5. Persist design with oligos to LIMS2.

* * *

INPUT DATA
==========

Design Parameters:
--------------
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
* phase - conditional
* name

Oligo Profile:
--------------
* oligo parameters
* define region oligos must be located in

### Conventional Deletion

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
   G5            U5      U-REGION      U3         D5      D-REGION      D3            G3
|======|------|======|-|          |-|======|---|======|-|          |-|======|------|======|
|------|                                                                                     > G5 Region Length
       |---------------|                                                                     > G5 Region Offset
              |------|                                                                       > U5 Region Length
                     |-|                                                                     > U5 Region Offset
                                    |------|                                                 > U3 Region Length
                                  |-|                                                        > U3 Region Offset
                                               |------|                                      > D5 Region Length
                                                      |-|                                    > D5 Region Offset
                                                                     |------|                > D3 Region Length
                                                                   |-|                       > D3 Region Offset
                                                                                   |------|  > G3 Region Length
                                                                   |---------------|         > G3 Region Offset
```


* * *

WORKFLOW
========

1: Specify Target Area
======================
Given a target gene with details of the exons that are being targetted we need to produce
a set of coordinates for the target region(s);

###input:
* target gene
* start exon
* end exon
* species
* assembly

###output:
* design coordinates

* * *

2: Oligo Target Regions
=======================
Given the target coordinates for the design plus the parameters for the oligos
produce oligo target region sequence files ( input to aos ).
For deletion designs just one target region ( region to delete ).
For knockout designs we will have 2 ( cassette insertion point plus loxp insertion point ).

Validate that we have the right design parameters for the given design type?

###input:
* design params
    * design coordinates
        * chromosome
        * strand
        * start
        * end
    * species
    * assembly
* oligo profile

###output: sequence for target region of each oligo
* G5 region sequence
* U5 region sequence
* U3 region sequence ( optional )
* D5 region sequence ( optional )
* D3 region sequence
* G3 region sequence

Sequence files must have fasta headers formated as such:
```
>oligo_name:start-end
eg
>U5:123124-123234
```

* * *

3: Produce Oligos
=================
Run AOS multiple times for each oligo, group and validate AOS output if needed.

###input:
* design type
* location of target region sequence files

###output:
* list of oligos for every target region


AOS Wrapper
-----------
Takes target sequence and output list of primers for that region.
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
inside bac ( but use genomes flanking sequence, 100k by default )

* * *

5: Find Best Global Oligo Pair
=============================
We need to carry out additional checks on the G5 and G3 oligos and then
find the best pair of oligos to use.

###input:
* G5 and G3 oligos

###output
* Best pair of G5 and G3 oligos

G Oligo Overlaps
----------------
G5 and G3 oligo sequence can not overlap

Best G Oligo Pair
-----------------
Find best combination of G5 and G3 oligos.

* * *

6: Create Design File
=====================

Create the yaml design file, that will be used in the next persist step.
Brings together all the data from the previous steps and formats it correctly.

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

* * *

7: Persist Design
=================
Once we have valid oligos for the target we persist it, to LIMS2.
Use the LIMS2 api to insert design.

###input:
* design data yaml file

###output:
* design stored in LIMS2
