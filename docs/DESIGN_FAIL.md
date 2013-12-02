GIBSON DESIGN FAIL
==================

PRIMER3
-------

### Failed to find primer pair in region

#### repeat masking too great
* Can lessen amount of repeat masking
* Go from full repeat mask to just a few classes ( trf && dust )
* Repeat masking done though information in Ensembl

#### low GC content
* Move the region

#### melting temp too high / low 
* To do with GC content I believe
* More the region

OLIGO VALIDATION
----------------

### Fails initial simple checks
* If it fails any of the simple checks something is very wrong, need to look at output carefully
* Simple checks include
    * Oligo length
    * Oligo sequence

### Oligo too close to another exon
* We can decrease the area we are looking for other exons in ( or turn off check )
* Move the region oligo is found in

### Fails genomic specificity check
* We may be too strict in finding 'hits'
* Could increase the strictness of what a hit is
* Again we can also just move the region the oligo is found in
* Check the specificiy as a oligo pair instead of individually? Will that work


REGION CHANGES
--------------

* 5F - Increase 5F ( 1000 ) offset
    * Increase in blocks of 500 bases ( max +3000? )
* 5R - Increase 5R-EF ( 200 ) offset
    * Increase in blocks on 50 bases ( max +400? )
* EF - Increase 5R-EF ( 200 ) offset
    * Increase in blocks on 50 bases ( max +400? )
* ER - Increase ER-3F ( 100 ) offset
    * Increase in blocks on 50 bases ( max +400? )
* 3F - Increase ER-3F ( 100 ) offset
    * Increase in blocks on 50 bases ( max +400? )
* 3R - Increate 3R ( 1000 ) offset
    * Increase in blocks of 500 bases ( max +3000? )

* ER-3F offset can be decreased to around 25 bases if needed.
* 5R-EF offset ( 200 ) should probably not be decreased  ( but try 150 if desperate )

* ER-3F to 5R-EF total length should not go above 1000 bases ( length of exon is important factor here )
