Human Genome for bwa:
/lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa

ONE: Align step
---------------
produces as sai file ( binary)

 bwa aln -n 3 -o 0 -N /lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa [test-oligos.fasta]

TODO:
fastq file instead of fasta file?
Is the output alignments always same length as oligo?

The options:
-n 3   The number of mismatches allowed over the entire sequence
-o 0   Disable gapped alignments by setting maximum allowed gaps to 0
-N     Disable iterative search to make sure all hits are found


TWO: convert align sai output to sam file
-----------------------------------------

 /software/solexa/bin/bwa samse -n 900000 /lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa  [test-oligos.sai] [test-oligos.fasta] > [test-oligos.sam]


THREE: Convert sam files to sorted bed files
--------------------------------------------

 /software/solexa/bin/aligners/bwa/current/xa2multi.pl [test-oligos.sam] | /software/solexa/bin/samtools view -bS - | /software/solexa/bin/samtools sort - [test-oligos.sorted]

What this actually does:
xa2multi.pl - the sam file made by the samse step only has a single entry per crispr, the rest are stored in the XA tag as cigar strings. This makes one entry per line instead
samtools view - converts the sam output from stdin to bam (output to stdout)
samtools sort - sorts the bam input from stdin and writes it to $FILESTEM.sorted.bam

view
----

I can probably filter out some matches here if I can figure out some of the command line options to the view command
The FLAG value may be of use here

-F 4 option should filter out unmapped alignments?

The second column in a SAM/BAM file is the flag column. They may seem confusing at first but the encoding allows details about a read to be stored by just using a few digits. The trick is to convert the numerical digit into binary, and then use the table to interpret the binary numbers, where 1 = true and 0 = false.

Here are some common BAM flags:

163: 10100011 in binary
147: 10010011 in binary
99: 1100011 in binary
83: 1010011 in binary

Interpretation of 10100011 (reading the binary from left to right):

1   the read is paired in sequencing, no matter whether it is mapped in a pair
1   the read is mapped in a proper pair (depends on the protocol, normally inferred during alignment)
0   the query sequence itself is unmapped
0   the mate is unmapped
0   strand of the query (0 for forward; 1 for reverse strand)
1   strand of the mate
0   the read is the first read in a pair
1   the read is the second read in a pair

 The MAPQ value can be used to figure out how unique an alignment is in the genome (large number, >10 indicate it's likely the alignment is unique).

One of the tags: NM gives the edit distance
The cigar string will only show something like 25M ( M can be match or mis-match )

create bed file
---------------

 bamToBed -i [test-oligos.sorted.bam] > [test-oligos.bed]


FOUR: Get sequence for alignments
---------------------------------

TODO: before this step, why not throw out oligos which have too many hits and would not pass?

fastaFromBed is a bedTools utility that takes a bed file and a reference genome, then outputs the locations and sequences:

  fastaFromBed -tab -fi /lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa -bed [test-oligos.bed] -fo [test-oligos.with-seqs.tsv]

Output not in format we can use, merge it with bed file
TODO: make a script to do this, I don't need a bed file as the final output

  perl ~ah19/work/paired_crisprs/merge_fasta.pl [test-oligos.bed] [test-oligos.with-seqs.tsv] > [test-oligos.with-seqs.bed]

Output I want, hit sequences for a given oligo

FIVE:

For each oligo:
* check there is one and only one exact match
    * If mulitple exact matches bad oligo
    * if no exact matches somethign has gone wrong
* Loop through each of the alignment sequences ( not including the exact match )
    * Check length of align sequence ( if its less than oligo length what to do ?)
    * May need to orient the oligo to find out the 3' region of it ( depends on target strand )
    * If the last 4-5 bases are not a exact match then we are probably okay
    * If the last 4-5 bases are a exact match,
        * If < 3 other bases are mismatch count as a hit?
        * If > 3 other bases are mismatch then not a hit?
    * CHECK above with Manousos
