# DESIGN-CREATION
Create a group of oligos ( a design ) that can be used to construct a vector that can will target and knock out a specific gene.
For details look at github [wiki](https://github.com/htgt/Design-Creation/wiki)

## Overview:

1. Specify target region for design.
2. Determine the coordinates of the regions the oligos will be found in.
3. Produce list of possible oligos/primers, using Primer3 or AOS.
4. Filter and rank oligos, pick the best one of each type.
5. Optionally Persist design with oligos to LIMS2 or WGE.

## Design Examples

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

### Conventional Deletion / Insertion

```
   G5               U5       TARGET       D3               G3
|======|---------|======|-|   >>>>   |-|======|---------|======|
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
   G5              U-REGION    TARGET    D-REGION             G3
|======|---------|==========|   >>>>   |==========|--------|======|
|------|                                                              > G5 Region Length
       |---------|                                                    > G5 Region Offset
                      |-|                                             > U Oligo Min Gap
                                            |-|                       > D Oligo Min Gap
                                                           |------|   > G3 Region Length
                                                |-----------------|   > G3 Region Offset
```
