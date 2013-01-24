DESIGN-CREATION
===============

Create a knock out design for a given target.

Below the basic plan for the software is explained.

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


3: Produce Oligos
===============
Wrapper around below:
Validation here.

To work out assembly coordiantes we use the offset information returned by aos for each oligo.
This information plus the oligo target region coordinates is enough to work out
the assembly coordinates for the oligos.

AOS Wrapper
-----------
Takes target sequence and output list of primers for that region.
Need to wrap up input and output for aos to produce usable output for next step.

###input:
* sequence files
* location of chr genome files
* design type
* other parameters to aos seem to get set, will not change

###output:
* list of oligos for each oligo type ( ranked )
* coordinate offset returned as well


4: Oligo Filtering
===============
We will have multiple oligos of each type, need to filter out bad ones and pick the 'best'
one of each type.

Do we only care about the one 'best' one we picked, will be need to examine the rest of the
oligos?

###input:
* oligos
* design type

###output:
* best oligo for each oligo type
* throw error if we can't find given oligo type

G Oligo Overlaps
----------------
G5 and G3 oligo sequence can not overlap

Oligo Specificity
-----------------
inside bac ( but use genomes flanking sequence 200k )

Best G Oligo Pair
-----------------
Find best combination of G5 and G3 oligos.


5: Persist Design
==============
Once we have valid oligos for the target we persist it, to LIMS2.
Use the LIMS2 api to insert design.

###input:
* target name
* species
* id? ( looks required in lims api, may need to change code here? )
* design type
* oligos
    * type
    * sequence
    * loci
        * assembly
        * chr name
        * start
        * end

###output:
* design stored in LIMS2
