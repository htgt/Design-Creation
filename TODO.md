FUNCTIONALITY
=============

### Expected Oligos
Can no longer use this list for everything, needs to be split up depending on:
* conditional / non conditional design
* block or location specified

### Need Config files for certain parameters:
* Need some sort of profile for different design types
* Oligo Target Region Definitions mainly
* Can use MooseX::SimpleConfig but:
    * only really use it with one log file
    * seems to suppress the --help option

Conditional Designs
-------------------

### Target Region Finder
Must take coordinates for U and D regions and split these regions in two.
These will be the individual U5, U3, D5 and D3 target regions.

### Expected Oligos
Add U3 and D5 to list for conditionals

### Find Valid U & D Region Oligos
Use min / max gap between U / D oligo params to get valid oligo pairs.
Need to balance between best aos oligos and oligo pair with smallest gap between themselves.

### Consolidate Design Data
Needs to look at U and D oligo pairs files, if they exist, to pick oligos now,
like it currently does for G oligos.

Location Specified Designs
--------------------------

### Overall
* Only interested in finding G5 and G3 oligos.
* But will need to produce sequence for the specified other oligos.
* Conditional designs skip the U / D oligo pair finder step.

### Target Region Finder
All the U / D oligos will have been specified, only need to find the G oligos.
Will need to take the coordinates for the U and D oligos and offset values for G oligos.
Only need to get target regions for G5 and G3.

### Find Oligos
Use the U and D coordinates to pull down sequence from ensemble for each oligo.

### Filter Oligos
Do we need to validate these oligos? check this.
Oligos should end up in validated oligo dir.


* * *
CHECKS
======

### Required Attributes Roles
* a consuming class must provide to required attributes / methods not another role
    * slight danger that a role is assuming the existance of a method / attribute

### Coordinate Checks
* InsDel design, check start before end for target region coordinates
* Conditional, for each block:
    * start before end
    * block length > 100 ( actually 100 is bad, min should be 102 assuming oligos are 50 bases )
    * U block before D block on +ve strand, vice versa on -ve strand

### Surplus Command Options
* We need to specify options such as design type for commands where that information is not needed
* Find these commands and remove them

### Combine t files
* Can run groups of tests through one test file, ( ask t file to run all tests in specific folder )


* * *

WOULD BE NICE
=============

### AOS speedup
* run aos with a smaller target file ( maybe the same one we send exonerate )
* check results against when the target file is the whole chromosome
* see if the speed up is worth it
