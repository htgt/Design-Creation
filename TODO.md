FUNCTIONALITY
=============

### Phase Finding Code : IMPORTANT
* Add code to find phase for given design
    * not all designs will have a phase, like the enhancer region designs
* What information do I need to work out phase:
    * Transcript
    * Target Exon
    * ?

### Need Config files for certain parameters:
* Need some sort of profile for different design types
* Oligo Target Region Definitions mainly
* Can use MooseX::SimpleConfig but:
    * only really use it with one log file
    * seems to suppress the --help option

### Automatically re-run oligo finding - WOULD BE NICE
* We may not find a good pair of G,D or U oligos
* Can we automatically re-run but ask AOS to increase number of oligos it outputs
* Another option is to tweak oligo region coordiantes automatically - but this would be MUCH harder

### Design Coordinate Pre-Check
* Additional check on coordinates to make sure they are sane
* Talk to Mark about what these checks may be.

Conditional Designs
-------------------

### Create Conditional Design Command
* Need one command to create a conditional design
* Modify the name of the run command which creates Ins / Del designs

Location Specified Designs
--------------------------

### Overall
* Only interested in finding G5 and G3 oligos.
* But will need to produce sequence for the specified other oligos.
* Conditional designs skip the U / D oligo pair finder step.

### Expected Oligos
Can no longer use this list for everything, needs to be split up depending on:
* block or location specified

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
CHANGES
=======

### Attribute Exception Class
* Add exception class when attribute does not exist for a given object

### Required Attributes Roles
* a consuming class must provide to required attributes / methods not another role
    * slight danger that a role is assuming the existance of a method / attribute

### Coordinate Checks
* InsDel design, check start before end for target region coordinates

### Surplus Command Options
* We need to specify options such as design type for commands where that information is not needed
* Find these commands and remove them

### Gap Oligo Pair Finder
* move log output to another folder

* * *
TESTING
=======

### Combine t files
* Can run groups of tests through one test file, ( ask t file to run all tests in specific folder )

### Test Objects
* Find a way to automate the creation of test objects, should not need to create a test object for every CmdRole I want to test

### Test::Class
* Use Test::Class framework to get some base tests written and factor out common code
    * base class would be Action.pm

### Design Method
* Specify deletion as design method in test objects
* Remove deletion method as default for this attribute

* * *

WOULD BE NICE
=============

### Chr and Strand
* Can I store the chromosome and strand in the oligo file?
    * stop having to pass it in as a command line option
    * do not have to keep consuming TargetSequence role
    * BUT - makes oligo file parsing a little more complicated

### AOS speedup
* run aos with a smaller target file ( maybe the same one we send exonerate )
* check results against when the target file is the whole chromosome
* see if the speed up is worth it
