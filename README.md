Design-Creation
===============

Create a knock out design for a given target.

DESIGN PARAMS:
--------------
* target ( just coordinate for now )
** genome / assembly
** chromosome name
** chromosome strand
** chromosome coordiantes
* design type
* phase - conditional
* name

OLIGO PROFILE:
--------------
* oligo parameters
* define region oligos must be located in

***

OLIGO TARGET REGIONS
====================
Given the target coordinates for the design plus the parameters for the oligos
produce oligo target region sequence files ( input to aos ).
For deletion designs just one target region ( region to delete ) 
For knockout designs we will have 2 ( cassette insertion point plus loxp insertion point )
Will there ever be more that 2 target regions?

Validate that we have the right design parameters for the given design type?

input:
* design params
* oligo profile

output: sequence for target region of each oligo
* G5 region sequence
* U5 region sequence
* U3 region sequence ( optional )
* D5 region sequence ( optional )
* D3 region sequence
* G3 region sequence

                               ||||
                               ||||
                               ||||
                             ||||||||
                              \||||/
                                \/
PRODUCE OLIGOS
===============
Wrapper around below:
Validation here.

AOS WRAPPER
-----------
Takes target sequence and output list of primers for that region.

Need to wrap up input and output for aos to produce usable output for next step.

###input:
* sequence files
* other parameters ?
* location of chr genome files
* design type
** will these other parameters need to change?

###output:
- list of oligos for each oligo type ( ranked )
- coordinate offset returned as well

                               ||||
                               ||||
                               ||||
                             ||||||||
                              \||||/
                                \/
OLIGO FILTERING
===============
We will have multiple oligos of each type, need to filter out bad ones and pick the 'best'
one of each type.

Do we only care about the one 'best' one we picked, will be need to examine the rest of the
oligos?

###input:
* oligos
* design type
* other parameters?

###output:
* best oligo for each oligo type
* throw error if we can't find given oligo type

G OLIGO OVERLAPS
----------------
G5 and G3 oligo sequence can not overlap

OLIGO SPECIFICITY
-----------------
inside bac ( but use genomes flanking sequence 200k )

BEST G OLIGO PAIR
-----------------

                               ||||
                               ||||
                               ||||
                             ||||||||
                              \||||/
                                \/

PERSIST DESIGN
==============
Once we have valid oligos for the target we persist it, to LIMS2.
Use the LIMS2 api to insert design.

###input:
* target name
* species
* id? ( looks required in lims api, may need to change code here? )
* phase?
* design type
* oligos
** type
** sequence
** loci
*** assembly
*** chr name
*** start
*** end

###output:
- design stored in LIMS2
