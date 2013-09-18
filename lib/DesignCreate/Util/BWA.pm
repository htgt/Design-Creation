package DesignCreate::Util::BWA;

=head1 NAME

DesignCreate::Util::BWA

=head1 DESCRIPTION

Align sequence(s) against a genome to find number of hits using BWA

=cut

use Moose;
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use Path::Class  qw( file );
use DesignCreate::Types qw( PositiveInt YesNo Species );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use YAML::Any qw( LoadFile DumpFile );
use IPC::Run 'run';
use Const::Fast;
use namespace::autoclean;

with qw( MooseX::Log::Log4perl );

const my $BWA_CMD => $ENV{BWA_CMD}
    || '/software/solexa/bin/bwa';

const my $SAMTOOLS_CMD => $ENV{SAMTOOLS_CMD}
    || '/software/solexa/bin/samtools';

const my $XA2MULTI_CMD => $ENV{XA2MULTI_CMD}
    || '/software/solexa/bin/aligners/bwa/current/xa2multi.pl';

# bedtools - install somewhere sensible
    # bamToBed
    # fastaFromBed

const my %BWA_GENOME_FILES => (
    Mouse => '/lustre/scratch105/vrpipe/refs/mouse/GRCm38/GRCm38_68.fa',
    Human => '/lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa',
);

has query_file => (
    is       => 'ro',
    isa      => AbsFile,
    coerce   => 1,
    required => 1,
);

has work_dir => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has species => (
    is       => 'ro',
    isa      => Species,
    required => 1,
);

has num_mismatches => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
    default  => 3,
);

has target_file => (
    is         => 'rw',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_target_file {
    my $self = shift;

    my $file = file( $BWA_GENOME_FILES{ $self->species } );
    return $file->absolute;
}

has sam_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_sam_file {
    return shift->work_dir->file('query.sam')->absolute;
}

has sorted_bam_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_sorted_bam_file {
    my $self = shift;

    my $file = $self->work_dir->file('query.sorted.bam')->absolute;
    unless ( $self->work_dir->contains( $file ) ) {
        DesignCreate::Exception::MissingFile->throw( file => $file, dir => $self->work_dir )
    }

    return $file;
}

# oligo seqs, all on +ve strand
has oligo_seqs => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_oligo_seqs {
    my $self = shift;
    my %oligo_seqs;

    my $seq_in = Bio::SeqIO->new( -fh => $self->query_file->openr, -format => 'fasta' );
    while ( my $seq = $seq_in->next_seq ) {
        $oligo_seqs{ $seq->display_id } = $seq->seq;
    }

    return \%oligo_seqs;
}

sub run_bwa_checks {
    my $self = shift;

    $self->run_bwa;
    $self->generate_bam_files;
    return $self->parse_bam_file;
}

=head2 run_bwa

Run the aln and samse steps of bwa.
Output is a sam file.

=cut
sub run_bwa {
    my $self = shift;
    $self->log->info( 'Running bwa commands' );

    my @aln_command = (
        $BWA_CMD,
        'aln',                         # align command
        "-n", $self->num_mismatches,   # number of mismatches allowed over sequence
        "-o", 0,                       # disable gapped alignments
        "-N",                          # disable iterative search to get all hits
        $self->target_file->stringify, # target genome file, indexed for bwa
        $self->query_file->stringify,  # query file
    );
    $self->log->debug( "BWA aln command: " . join( ' ', @aln_command ) );

    my $bwa_aln_file = $self->work_dir->file('query.sai')->absolute;
    my $bwa_aln_log_file = $self->work_dir->file( 'bwa_aln.log' )->absolute;
    run( \@aln_command,
        '<', \undef,
        '>', $bwa_aln_file->stringify,
        '2>', $bwa_aln_log_file->stringify
    ) or DesignCreate::Exception->throw(
            "Failed to run bwa aln command, see log file: $bwa_aln_log_file" );

    my @samse_command = (
        $BWA_CMD,
        'samse',
        '-n 900000',
        $self->target_file->stringify,
        $bwa_aln_file->stringify,
        $self->query_file->stringify,
    );
    $self->log->debug( "BWA samse command: " . join( ' ', @samse_command ) );

    my $bwa_samse_log_file = $self->work_dir->file( 'bwa_samse.log' )->absolute;
    run( \@samse_command,
        '<', \undef,
        '>', $self->sam_file->stringify,
        '2>', $bwa_samse_log_file->stringify
    ) or DesignCreate::Exception->throw(
            "Failed to run bwa samse command, see log file: $bwa_samse_log_file" );

    return;
}

=head2 generate_bam_files

Take sam file output from bwa and generate sorted bam files.
    # /software/solexa/bin/aligners/bwa/current/xa2multi.pl [test-oligos.sam]
    # | /software/solexa/bin/samtools view -bS -
    # | /software/solexa/bin/samtools sort - [test-oligos.sorted]

=cut
sub generate_bam_files {
    my ( $self ) = @_;
    my ( $out, $err ) =  ( "", "" );
    $self->log->info( 'Generate sorted bam files' );

    my @xa2multi_command = (
        $XA2MULTI_CMD,
        $self->sam_file->stringify,
    );
    $self->log->debug( "xa2multi command: " . join( ' ', @xa2multi_command ) );

    my $xa2multi_file = $self->work_dir->file('query.multi.sam')->absolute;
    my $xa2multi_log_file = $self->work_dir->file('xa2multi.log')->absolute;
    run( \@xa2multi_command, '<', \undef, '>', $xa2multi_file->stringify, '2>', \$err)
        or DesignCreate::Exception->throw(
            "Failed to run xa2multi command: $err" );

    my @view_command = (
        $SAMTOOLS_CMD,
        'view',                    #
        '-bS',                     #
        $xa2multi_file->stringify,
    );
    $self->log->debug( "samtools view command: " . join( ' ', @view_command ) );

    my $samtools_view_file = $self->work_dir->file('query.bam')->absolute;
    $err = "";
    run( \@view_command, '<', \undef, '>', $samtools_view_file->stringify, '2>', \$err)
        or DesignCreate::Exception->throw(
            "Failed to run samtools view command: $err" );

    #TODO sam files contain useful info not in bed file sp12 Mon 16 Sep 2013 13:00:36 BST
    # can we parse and make use of this

    my $samtools_sort_file = $self->work_dir->file('query.sorted')->absolute;
    my @sort_command = (
        $SAMTOOLS_CMD,
        'sort',                         #
        $samtools_view_file->stringify,
        $samtools_sort_file->stringify,
    );
    $self->log->debug( "samtools sort command: " . join( ' ', @sort_command ) );

    #TODO do I even need to sort this? sp12 Mon 16 Sep 2013 12:53:41 BST
    $err = "";
    run( \@sort_command, '<', \undef, '>', \$out, '2>', \$err)
        or DesignCreate::Exception->throw(
            "Failed to run samtools sort command: $err" );

}

=head2 parse_bam_file

Parse sorted bam files into output we can use.
Need to grab sequence of alignment.

=cut
sub parse_bam_file {
    my ( $self  ) = @_;
    my ( $out, $err ) =  ( "", "" );
    # bamToBed -i [test-oligos.sorted.bam] > [test-oligos.bed]

    my @bamToBed_command = (
        'bamToBed',
        "-i", $self->sorted_bam_file->stringify,
    );
    $self->log->debug( "bamToBed command: " . join( ' ', @bamToBed_command ) );

    my $bed_file = $self->work_dir->file('query.bed')->absolute;
    run( \@bamToBed_command, '<', \undef, '>', $bed_file->stringify, '2>', \$err,)
        or DesignCreate::Exception->throw(
            "Failed to run bamToBed command: $err" );

    #TODO filter out oligos with too many hits here sp12 Mon 16 Sep 2013 12:59:57 BST
    # should save a lot of time in the next step

    # fastaFromBed -tab -fi /lustre/scratch105/vrpipe/refs/human/ncbi37/hs37d5.fa -bed [test-oligos.bed] -fo [test-oligos.with-seqs.tsv]
    #TODO outpu in fasta format sp12 Tue 17 Sep 2013 10:19:08 BST
    my $seq_file = $self->work_dir->file('query.seqs.tsv')->absolute;
    my @fastaFromBed_command = (
        'fastaFromBed',
        '-tab',                               # write output in tab delimited format
        '-fi', $self->target_file->stringify, # target genome file, indexed for bwa
        '-bed', $bed_file->stringify,         # input file of alignments
        '-fo', $seq_file->stringify,          # output file
    );
    $self->log->debug( "fastaFromBed command: " . join( ' ', @fastaFromBed_command ) );

    run( \@fastaFromBed_command, '<', \undef, '>', \$out, '2>', \$err,)
        or DesignCreate::Exception->throw(
            "Failed to run fastaFromBed command: $err" );

    my %alignments;
    # merge bed data with seq data
    my $seq_fh = $seq_file->openr;
    my $bed_fh = $bed_file->openr;
    while ( my $bed_line = <$bed_fh> ) {
        my $seq_line = <$seq_fh>;

        my ( $location, $seq ) = split /\s+/, $seq_line;
        #the location needs to be further split to match the bed file format
        my ( $seq_chr, $seq_start, $seq_end ) = $location =~ /(.+):(\d+)-(\d+)/;

        my ( $chr, $start, $end, $name, $score, $strand ) = split /\s+/, $bed_line;

        #make sure the locations from each file are the same or everything would be wrong
        if ( $chr eq $seq_chr and $start == $seq_start and $end == $seq_end ) {
            push @{ $alignments{ $name } }, {
                chr    => $chr,
                start  => $start,
                end    => $end,
                strand => $strand,
                score  => $score,
                seq    => $seq,
            };
        }
        else {
            die "$seq_line doesn't match $bed_line!";
        }
    }

    return \%alignments;
}

sub hamming_distance {
    #use string xor to get the number of mismatches between the two strings.
    #the xor returns a string with the binary digits of each char xor'd,
    #which will be an ascii char between 001 and 255. tr returns the number of characters replaced.
    die "Strings passed to hamming distance differ" if length($_[0]) != length($_[1]);
    return (uc($_[0]) ^ uc($_[1])) =~ tr/\001-\255//;
}


__PACKAGE__->meta->make_immutable;

1;

__END__
