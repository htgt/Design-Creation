FUNCTIONALITY
=============

### Constants
* Specified same constant in different places
* Create a constants file to store all these values

### Design Parameters
* Store parameters for given design in a yaml file
* use it to look up design info, like strand, chr, species, assembly, etc etc
* store parameters here, like target region coordinates, offsets etc etc
* for each command add values to this file as needed.
    * oligo-target-region will add design targeting parameters
    * find-oligos will add aos parameters
    * filter-oligos will add any filter criteria parameters
    * etc
* Add attribute for this design parameters file in Action.pm
* Also add method to add to, and read data from the file
* Probably store data in a seperate attribute - Hash
* Currently one role has a bunch of attributes and sequence getting code
    * 
* IDEA: Store target region start and end info for oligos in LIMS2
    * just adding 2 more fields
    * will be able to deduce original critical / deleted regions
    * BUT - can we lift over these coordinates to another assembly??

### Design Meta Information
* Store design meta information in LIMS2
* Storing the design parameters would be nice.
* Store the version of the software used to create the design

### Need Config files for certain parameters:
* Need some sort of profile for different design types
* Oligo Target Region Definitions mainly
* Can use MooseX::SimpleConfig but:
    * only really use it with one log file
    * seems to suppress the --help option

### Split Sequence Gathering from Attributes
* Currently one role has a bunch of attributes and sequence getting code
* Split into multiple roles, must do after Design Parameters Work 

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

PROBLEMS
========

### Required Attributes Roles
* a consuming class must provide to required attributes / methods not another role
    * slight danger that a role is assuming the existance of a method / attribute

### Dir / File Deletion
If you run a design into the same folder twice, and the first run gets further than the second one:
there maybe misleading data in the folder, because data from first run will not be over-written / deleted

* * *

TESTING
=======

### Test Action.pm
* Consider using this as the base class instead of the cut down version
    * would need to remove certain roles, methods etc?

### Role::AOS
* Factor the tests out for this role into seperate test class

* * *

FUTURE FUNCTIONALITY
====================

### Phase Finding Code
* For now just specify a phase of -1000 or something clearly not correct
* Add code to find phase for given design
    * not all designs will have a phase, like the enhancer region designs
* What information do I need to work out phase:
    * Transcript
    * Target Exon

### Automatically re-run oligo finding - WOULD BE NICE
* We may not find a good pair of G,D or U oligos
* Can we automatically re-run but ask AOS to increase number of oligos it outputs
* Another option is to tweak oligo region coordiantes automatically - but this would be MUCH harder
* Can call expand on a slice, maybe use this feature?

### Design Coordinate Pre-Check
* Additional check on coordinates to make sure they are sane
* Talk to Mark about what these checks may be.

* * *

WOULD BE NICE
=============

### AOS speedup
* run aos with a smaller target file ( maybe the same one we send exonerate )
* check results against when the target file is the whole chromosome
* see if the speed up is worth it
