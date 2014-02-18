# Primer3 Input Notes

## Sequence Inputs

### SEQUENCE_TEMPLATE (nucleotide sequence; default empty)
* The sequence from which to choose primers. The sequence must be presented 5' -> 3'

### SEQUENCE_TARGET (interval list; default empty)
* If one or more targets is specified then a legal primer pair must flank at least one of them
* We only set one target

### There are many other options that can be set:
* areas where primers can not be picked
* areas where primers picked from ( pairs or not )
* overlaps, areas were primers must overlap
* can specify left or right primer ( let primer3 pick the other )
* force primers 5' or 3' end to a specific position


## Global Inputs

### PRIMER_TASK (string; default generic)
* what primers to pick ( e.g pairs, single etc )
* default used: generic - picks primer pairs

### PRIMER_NUM_RETURN (int; default 5)
* Max number of primers to return
* we default to 12
* returned by order, sorted on quality

### PRIMER_PRODUCT_SIZE_RANGE (size range list; default 100-300)
* list of size of the allowed product size
* we currently use 300-3000

### PRIMER_OPT_SIZE (int; default 20)
* optimum primer size
* we use 25

### PRIMER_MAX_SIZE (int; default 27)
* max size of primer ( can not exceed 35 )
* we use 28

### PRIMER_MIN_SIZE (int; default 18)
* minumum size of primer
* we use 22

### PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE (int; default -1)
* When returning multiple primer pairs, the minimum number of base pairs between the 3' ends of any two left primers.
* We have specified a value of 6

### PRIMER_OPT_GC_PERCENT (float; default 50.0)
* optimum gc percentage
* we use 50%

### PRIMER_MAX_GC (float; default 80.0)
* max gc percentage
* we use 60%

### PRIMER_MIN_GC (float; default 20.0)
* minimum gc percentage
* we use 40%

### PRIMER_GC_CLAMP (int; default 0)
* Require the specified number of consecutive Gs and Cs at the 3' end of both the left and right primer.

### PRIMER_MAX_END_GC (int; default 5)
* The maximum number of Gs or Cs allowed in the last five 3' bases of a left or right primer.

### PRIMER_MIN_TM (float; default 57.0)
* Minimum acceptable melting temperature (Celsius) for a primer oligo.

### PRIMER_OPT_TM (float; default 60.0)
* Optimum melting temperature (Celsius) for a primer.

### PRIMER_MAX_TM (float; default 63.0)
* Maximum acceptable melting temperature (Celsius) for a primer oligo.

### PRIMER_PAIR_MAX_DIFF_TM (float; default 100.0)
* Maximum acceptable (unsigned) difference between the melting temperatures of the left and right primers.

### PRIMER_TM_FORMULA (int; default 1)
* uses formula from this paper http://dx.doi.org/10.1073/pnas.95.4.1460 
* other options available about salt cation concentrations and dna concentrations ( helps with TM calculations )

### other options of possible interest
* force 5' or 3' end of primer to match a specific sequence
* set custom penelty weight on lots of values


## Primer Checks
Options for some of the other checks Primer3 carries out on the primers.

### PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT (boolean; default 1)
* If the associated value = 1, then primer3 will use thermodynamic models to calculate the the propensity of oligos to form hairpins and dimers.

### PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT (boolean; default 0)
* If the associated value = 1, then primer3 will use thermodynamic models to calculate the the propensity of oligos to anneal to undesired sites in the template sequence.

### PRIMER_LOWERCASE_MASKING (int; default 0)
* This option allows for intelligent design of primers in sequence in which masked regions (for example repeat-masked regions) are lower-cased
* we set this to 1
* A value of 1 directs primer3 to reject primers overlapping lowercase a base exactly at the 3' end.
* This property relies on the assumption that masked features (e.g. repeats) can partly overlap primer, but they cannot overlap the 3'-end of the primer. 
* In other words, lowercase bases at other positions in the primer are accepted, assuming that the masked features do not influence the primer performance if they do not overlap the 3'-end of primer.

### PRIMER_MAX_SELF_ANY (decimal, 9999.99; default 8.00)
* Tendency of a primer to bind to itself (interfering with target sequence binding). It will score ANY binding occurring within the entire primer sequence.
* It is the maximum allowable local alignment score when testing a single primer for (local) self-complementarity and the maximum allowable 
  local alignment score when testing for complementarity between left and right primers

### PRIMER_MAX_SELF_ANY_TH (decimal, 9999,99; default 47.00)
* The same as PRIMER_MAX_SELF_ANY but all calculations are based on thermodynamical approach. The melting temperature of the most stable structure is calculated.

### PRIMER_MAX_SELF_END (decimal, 9999.99; default 3.00)
* Tries to bind the 3'-END to a identical primer and scores the best binding it can find. 
  This is critical for primer quality because it allows primers use itself as a target and amplify a short piece (forming a primer-dimer). 
  These primers are then unable to bind and amplify the target sequence.

### PRIMER_MAX_HAIRPIN_TH (float; default 47.0)
* This is the most stable monomer structure of internal oligo calculated by thermodynamic approach. 
  The hairpin loops, bulge loops, internal loops, internal single mismatches, dangling ends, terminal mismatches have been considered. 
  This parameter is calculated only if PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT=1. The default value is 10 degrees lower than the default value of PRIMER_MIN_TM.

### PRIMER_MAX_END_STABILITY (float, 999.9999; default 100.0)
* The maximum stability for the last five 3' bases of a left or right primer. Bigger numbers mean more stable 3' ends. 
  The value is the maximum delta G (kcal/mol) for duplex disruption for the five 3' bases as calculated using the nearest-neighbor parameter values specified by the option of PRIMER_TM_FORMULA 

### PRIMER_MAX_POLY_X (int; default 5)
* The maximum allowable length of a mononucleotide repeat, for example AAAAAA.

### MISPRIMING
* I think this is to do with areas to avoid amplifying?

