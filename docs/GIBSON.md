GIBSON OLIGO DESIGN NOTES
=========================

New process to create knockouts, required a new method for finding oligos.

Oligo Regions
-------------

We define 3 seperate regions which we want to find primer pairs for.

### +ve Stranded Design

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

### -ve Stranded Design

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

### Design Notes
* Want to keep gap between 5R-EF and ER-3F oligos down to a minumum 
    * This corresponds to the deleted region
* Want to keep exon region small, default gaps are 200 5' and 100 3'
* Arms are smaller than traditional designs, around 1000 base gap ( can be pushed out to say 2000 )
* Ideally we should be able to independantly set the offset for oligos in the inner regions. 

Primer3
-------
Use Primer3 to find oligos, we can do this now because oligos are no longer 50 bases long.

For each of the 3 regions we define the areas where the forward primer should be found and a 
seperate area where the reverse primer should be found.

### General Settings for Primer3
* GC content around 50%
* Ideally oligo is 25 bases long.
* Send in repeat masked sequence
* Multiple other options we can tweak

### Strand / Revcom workflow
* Primer3 expects sequence in 5' to 3' direction
* Primers all outputed in +ve strand
* If design is on +ve strand then we just send in the sequence for the target region slice ( always on +ve strand )
* If design is on -ve strand then the target region slice is inverted ( not revcomped  ) so it runs from 5' to 3' direction
* Primer returns the forward ( left ) primer on the +ve strand and the reverse ( right ) primer on the -ve strand.
* When we get the results from Primer3 we want to parse the data and store the oligo in the +ve strand.
* If +ve strand design then revcomp the reverse primer
* If -ve strand design them revcomp to forward primer


Oligo Filtering
---------------

### Exon Adjacent Check
* The middle oligos ( 3F, ER, EF, 5R ) must not hit exonic sequence, at least 100 bases away
    * We are looking at exons for any gene on either strand here
    * Not just coding exons for now

### Genomic Specificity Check
* Check against the whole genome.
* Discard if we have multiple exact hits.
* The 3' of the oligo is critical to the process.
    * A oligo with hits against the genome but no hits in the 3' end of the oligo could still be okay.
    * Generally this means the last 4-5 bases of the oligo.
    * The number of bases 3' of the oligo depend on the melting temp of the oligo.
