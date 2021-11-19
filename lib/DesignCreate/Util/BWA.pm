package DesignCreate::Util::BWA;

=head1 NAME

DesignCreate::Util::BWA

=head1 DESCRIPTION

Align sequence(s) against a genome to find number of hits using BWA aln

=cut

use Moose;
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use DesignCreate::Types qw( PositiveInt NaturalNumber Species );
use DesignCreate::Constants qw(
    $BWA_SERVER
    $BWA_CMD
    $SAMTOOLS_CMD
    $XA2MULTI_CMD
    %BWA_GENOME_FILES
);
use WebAppCommon::Util::RemoteFileAccess;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Path::Class  qw( file );
use YAML::Any qw( LoadFile DumpFile );
use IPC::Run 'run';
use Const::Fast;
use namespace::autoclean;
use Bio::SeqIO;
use IO::String;
use Data::Dumper;
use Path::Class;
use Data::UUID;

with qw( MooseX::Log::Log4perl );

has primers => (
    is  => 'ro',
    isa => 'HashRef',
);

has design_id => (
    is      => 'ro',
    isa     => 'Str',
    default => ''
);

has well_id => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has api => (
    is  => 'ro',
    isa => 'WebAppCommon::Util::RemoteFileAccess',
    lazy_build => 1,
);

sub _build_api {
    return WebAppCommon::Util::RemoteFileAccess->new({server => $BWA_SERVER});
}

has work_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_work_dir {
    my $self = shift;
    my $unique_string = Data::UUID->new()->create_str();
    my $root_dir = $ENV{'LIMS2_BWA_OLIGO_DIR'} // '/var/tmp/bwa';
    my $work_dir = dir($root_dir, $self->well_id . '_' . $unique_string);
    $self->api->make_dir($work_dir) == 0
        or DesignCreate::Exception->throw("Could not create $work_dir");
    return $work_dir;
}

has query_file => (
    is         => 'ro',
    isa        => 'Path::Class::File',
    lazy_build => 1,
);

sub _build_query_file {
    my $self = shift;
    my $file_content = '';
    my $file_content_io = IO::String->new($file_content);
    my $seq_out = Bio::SeqIO->new( -fh => $file_content_io, -format => 'fasta' );
    if ($self->primers->{'left'} || $self->primers->{'right'}) {
        foreach my $oligo ( sort keys %{$self->primers->{'left'}} ) {
            my $fasta_seq = Bio::Seq->new(
                -seq => $self->primers->{'left'}->{$oligo}->{seq},
                -id  => $oligo
            );
            $seq_out->write_seq($fasta_seq);
        }
        foreach my $oligo ( sort keys %{$self->primers->{'right'}} ) {
            my $fasta_seq = Bio::Seq->new(
                -seq => $self->primers->{'right'}->{$oligo}->{seq},
                -id  => $oligo
            );
            $seq_out->write_seq($fasta_seq);
        }
    } else {
        foreach my $oligo ( sort keys %{$self->primers} ) {
            my $fasta_seq = Bio::Seq->new(
                -seq => $self->primers->{$oligo}->{seq},
                -id  => $oligo
            );
            $seq_out->write_seq($fasta_seq);
        }
    }
    my $query_fasta = $self->work_dir->file($self->design_id . '_oligos.fasta');
    $self->api->post_file_content($query_fasta, $file_content) == 0
        or DesignCreate::Exception->throw("Could not create $query_fasta");
    return $query_fasta;
}

has species => (
    is       => 'ro',
    isa      => Species,
    required => 1,
);

has num_bwa_threads => (
    is      => 'ro',
    isa     => PositiveInt,
    default => 2,
);

# default of 2 only gets hits with > 90% similarity
has num_mismatches => (
    is       => 'ro',
    isa      => NaturalNumber,
    required => 1,
    default  => 2,
);

has three_prime_check => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has delete_bwa_files => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has target_file => (
    is         => 'rw',
    isa        => 'Path::Class::File',
    lazy_build => 1,
);

sub _build_target_file {
    my $self = shift;

    my $file = file( $BWA_GENOME_FILES{ $self->species } );
    return $file->absolute;
}

has sam_multi_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_sam_multi_file {
    return shift->work_dir->file('query.multi.sam')->absolute;
}

has bed_file => (
    is         => 'ro',
    isa        => AbsFile,
    lazy_build => 1,
);

sub _build_bed_file {
    return shift->work_dir->file('query.bed')->absolute;
}

# oligo seqs, all on +ve strand
has oligo_seqs => (
    is                => 'ro',
    isa               => 'HashRef',
    lazy_build        => 1,
    traits            => [ 'Hash' ],
    handles           => {
        get_oligo_seq => 'get',
    }
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

has matches => (
    is  => 'rw',
    isa => 'HashRef',
);

=head2 run_bwa_checks

Run bwa alignments along with multiple other steps to parse this output.
Generate number of hits a oligo has against the genome.

=cut
sub run_bwa_checks {
    my $self = shift;
    $self->log->info( 'Running bwa alignment checks' );

    $self->generate_sam_file;
    my $oligo_hits = $self->oligo_hits;
    #NOTE This is not implemented
    if ( $self->three_prime_check ) {
        $self->generate_bed_file;
        $self->oligo_hits_three_prime_check( $oligo_hits );

        my $three_prime_check_file = $self->work_dir->file( 'three_prime_check.yaml' );
        DumpFile( $three_prime_check_file, $self->matches );
    }
    else {
        # the basic oligo hits info is good enough
        $self->matches( $oligo_hits );
        $self->sam_multi_file->remove if $self->delete_bwa_files;
    }

    $self->bed_file->remove if $self->delete_bwa_files;

    return;
}

=head2 generate_sam_file

Run the aln and samse steps of bwa, output is a sam file.
* bwa aln - perform alignments of oligo sequences against whole genome
* bwa samse - convert sai file from bwa aln step into a sam file
* xa2multi - put each hit for oligo into seperate line in sam file

=cut
sub generate_sam_file {
    my $self = shift;
    $self->log->info( 'Generating sam file' );

    my $bwa_aln_file = $self->work_dir->file('query.sai')->absolute;
    my $bwa_aln_log_file = $self->work_dir->file( 'bwa_aln.log' )->absolute;
    my $aln_command = join( ' ', (
        'ssh', $BWA_SERVER,
        "\"$BWA_CMD",
        'aln',                         # align command
        "-n", $self->num_mismatches,   # number of mismatches allowed over sequence
        "-o", 0,                       # disable gapped alignments
        "-N",                          # disable iterative search so we get all hits
        "-t", $self->num_bwa_threads,  # specify number of threads
        $self->target_file->stringify, # target genome file, indexed for bwa
        $self->query_file->stringify,  # query file with oligo sequences
        '>', $bwa_aln_file->stringify,
        '2>', "$bwa_aln_log_file\"",
    ));
    $self->log->debug( "BWA aln command: $aln_command");

    system($aln_command) == 0
        or DesignCreate::Exception->throw(
        "Failed to run bwa aln command, see log file: $bwa_aln_log_file");

    my $sam_file = $self->work_dir->file('query.sam')->absolute;
    my $bwa_samse_log_file = $self->work_dir->file( 'bwa_samse.log' )->absolute;
    my $samse_command = join( ' ', (
        'ssh', $BWA_SERVER,
        "\"$BWA_CMD",
        'samse',                       # converts sai file (binary) to sam file
        '-n 900000',                   # max number of allowed hits per oligo
        $self->target_file->stringify, # target genome file
        $bwa_aln_file->stringify,      # sai binary file, output from bwa aln step
        $self->query_file->stringify,  # query file with oligo sequences
        '>', $sam_file->stringify,
        '2>', "$bwa_samse_log_file\"",
    ));
    $self->log->debug( "BWA samse command: $samse_command");

    system($samse_command) == 0
        or DesignCreate::Exception->throw(
        "Failed to run bwa samse command, see log file: $bwa_samse_log_file");

    my $xa2multi_log_file = $self->work_dir->file('xa2multi.log')->absolute;
    my $xa2multi_command = join( ' ', (
        'ssh', $BWA_SERVER,
        "\"$XA2MULTI_CMD",
        $sam_file->stringify, # sam file output from samse step
        '>', $self->sam_multi_file->stringify,
        '2>', "$xa2multi_log_file\"",
    ));
    $self->log->debug( "xa2multi command: $xa2multi_command");

    system($xa2multi_command) == 0
        or DesignCreate::Exception->throw(
        "Failed to run xa2multi command, see log file: $xa2multi_log_file");

    if ( $self->delete_bwa_files ) {
        system("ssh $BWA_SERVER \"rm $sam_file\"") == 0
            or DesignCreate::Exception->throw("Could not remove $sam_file");
        system("ssh $BWA_SERVER \"rm $bwa_aln_file\"") == 0
            or DesignCreate::Exception->throw("Could not remove $bwa_aln_file");
    }

    return;
}

=head2 oligo_hits

Calculate number of hits each oligo got against the genome.
This is done by parsing the data from the sam multi file.

=cut
sub oligo_hits {
    my ( $self ) = @_;
    $self->log->info( 'Calculating oligo hits' );
    my %oligo_hits;

    my $file_content = $self->api->get_file_content($self->sam_multi_file);
    my $fh = IO::String->new($file_content);
    while ( <$fh> ) {
        next if /^@/;
        my @data = split /\t/;
        my $id           = $data[0];
        my $flag         = $data[1];
        my $chromosome   = $data[2];
        my $chr_start    = $data[3];
        my $score        = $data[4];
        my $sub_opt_hits = $data[14];

        if ( $self->_primary_alignment( $flag ) ) {
            if ( $self->_segment_unmapped( $flag ) ) {
                $oligo_hits{$id}{unmapped} = 1;
                next;
            }
            $oligo_hits{$id}{hits}++;

            $oligo_hits{$id}{score} = $score;
            $oligo_hits{$id}{sub_opt_hits} = $sub_opt_hits;
            $oligo_hits{$id}{chr} = $chromosome;
            $oligo_hits{$id}{start} = $chr_start;

            my $threshold = $ENV{BWA_GENOMIC_THRESHOLD} || 30;
            # score ok above 30 look to be totally unique
            if ( $score > $threshold ) {
                $oligo_hits{$id}{unique_alignment} = 1;
            }
        }
        else {
            $oligo_hits{$id}{hits}++;
            push @{ $oligo_hits{$id}{hit_locations} }, { chr => $chromosome, start => $chr_start };
        }
    }

    my $oligo_hits_file = $self->work_dir->file( 'oligo_hits.yaml' );
    $self->api->post_file_content($oligo_hits_file, Dumper(\%oligo_hits));

    return \%oligo_hits;
}

=head2 _segment_unmapped

Return true if segment unmapped SAM flag is true.

=cut
sub _segment_unmapped {
    my ( $self, $flag ) = @_;
    if ($flag & 0x4){
        return 1;
    }
    return;
}

=head2 _primary_alignment

Return true if secondary alignment SAM flag is false.

=cut
sub _primary_alignment {
    my ( $self, $flag ) = @_;
    if ($flag & 0x100){
        return;
    }
    return 1;
}

=head2 generate_bed_file

Take sam file output from previous steps and generate bed file.
* samtools view - convert sam file to bam file
* samtools sort - sort bam file by left most coordinate, in chromosome order
* bamToBed - convert bam file to bed file

=cut
sub generate_bed_file {
    my ( $self ) = @_;
    my ( $out, $err ) = ( "","" );
    $self->log->info( 'Generating bed file' );

    my @view_command = (
        $SAMTOOLS_CMD,
        'view',                           # convert same file to bam file
        '-b',                             # output in bam format
        '-S',                             # input is sam file
        $self->sam_multi_file->stringify, # sam file
    );
    $self->log->debug( "samtools view command: " . join( ' ', @view_command ) );

    $err = "";
    my $bam_file = $self->work_dir->file('query.bam')->absolute;
    run( \@view_command, '<', \undef, '>', $bam_file->stringify, '2>', \$err)
        or DesignCreate::Exception->throw(
            "Failed to run samtools view command: $err" );

    my $temp_file = $self->work_dir->file('query.sorted')->absolute;
    my @sort_command = (
        $SAMTOOLS_CMD,
        'sort',                         # sort by left most coordinate
        $bam_file->stringify,           # input bam file
        $temp_file->stringify,          # output - sorted bam file
    );
    $self->log->debug( "samtools sort command: " . join( ' ', @sort_command ) );

    $err = "";
    run( \@sort_command, '<', \undef, '>', \$out, '2>', \$err)
        or DesignCreate::Exception->throw(
            "Failed to run samtools sort command: $err" );

    my $sorted_bam_file = $self->work_dir->file('query.sorted.bam')->absolute;
    DesignCreate::Exception::MissingFile->throw( file => $sorted_bam_file, dir => $self->work_dir )
        unless $self->work_dir->contains( $sorted_bam_file );

    my @bamToBed_command = (
        'bamToBed',                        # convert bam to bed file
        "-i", $sorted_bam_file->stringify, # input bam file
    );
    $self->log->debug( "bamToBed command: " . join( ' ', @bamToBed_command ) );

    run( \@bamToBed_command, '<', \undef, '>', $self->bed_file->stringify, '2>', \$err,)
        or DesignCreate::Exception->throw(
            "Failed to run bamToBed command: $err" );

    if ( $self->delete_bwa_files ) {
        $bam_file->remove;
        $sorted_bam_file->remove;
        $self->sam_multi_file->remove;
    }

    return;
}

=head2 oligo_hits_three_prime_check

When looks at hits the three prime end of the oligo is critical.
So a hit on a oligo where the mismatches occur in the last 3-4 three prime bases of
the oligo should not count

This involves fetching the sequence of the alignments which can be very time consuming.

=cut
sub oligo_hits_three_prime_check {
    my ( $self, $oligo_hits ) = @_;

    my $oligo_alignments = $self->fetch_alignment_sequence( $oligo_hits );

    #TODO add 3' oligo alignment check sp12 Wed 18 Sep 2013 10:32:49 BST
    # temp code, need to replace with 3' check
    my %matches;
    for my $oligo ( keys %{ $oligo_alignments } ) {
        for my $alignment ( @{ $oligo_alignments->{ $oligo } } ) {
            if ( $alignment->{percent_hit}  == 100 ) {
                $matches{$oligo}{'exact_matches'}++;
            }
            elsif ( $alignment->{percent_hit}  >= 90 ) {
                $matches{$oligo}{'hits'}++;
            }
        }
    }

    $self->matches( \%matches );

    return;
}

=head2 fetch_alignment_sequence

Grab sequence for alignments found by bwa using fastaFromBed script.
* fastaFromBed - get sequence for each alignment

This can be a very time consuming process depending on the number of hits.

=cut
sub fetch_alignment_sequence {
    my ( $self, $oligo_hits ) = @_;

    #TODO filter out oligos with too many hits here sp12 Mon 16 Sep 2013 12:59:57 BST
    # should save a lot of time in the next step, use $oligo_hits

    #TODO output in fasta format sp12 Tue 17 Sep 2013 10:19:08 BST
    my $seq_file = $self->work_dir->file('query.seqs.tsv')->absolute;
    my @fastaFromBed_command = (
        'fastaFromBed',                       # get sequence for each alignment
        '-tab',                               # write output in tab delimited format
        '-fi', $self->target_file->stringify, # target genome file, indexed for bwa
        '-bed', $self->bed_file->stringify,   # input file of alignments
        '-fo', $seq_file->stringify,          # output file
        '-s'                                  # take notice of strand
    );
    $self->log->debug( "fastaFromBed command: " . join( ' ', @fastaFromBed_command ) );

    my ( $out, $err ) =  ( "", "" );
    run( \@fastaFromBed_command, '<', \undef, '>', \$out, '2>', \$err,)
        or DesignCreate::Exception->throw(
            "Failed to run fastaFromBed command: $err" );

    my %alignments;
    # merge bed data with seq data
    my $seq_fh = $seq_file->openr;
    my $bed_fh = $self->bed_file->openr;
    while ( my $bed_line = <$bed_fh> ) {
        my $seq_line = <$seq_fh>;

        my ( $location, $seq ) = split /\s+/, $seq_line;
        #the location needs to be further split to match the bed file format
        my ( $seq_chr, $seq_start, $seq_end ) = $location =~ /(.+):(\d+)-(\d+)/;

        my ( $chr, $start, $end, $name, $score, $strand ) = split /\s+/, $bed_line;

        #make sure the locations from each file are the same or everything would be wrong
        if ( $chr eq $seq_chr and $start == $seq_start and $end == $seq_end ) {
            push @{ $alignments{ $name } }, {
                chr         => $chr,
                start       => $start,
                end         => $end,
                strand      => $strand,
                bwa_score   => $score,
                seq         => $seq,
                percent_hit => $self->calculate_percent_alignment( $name, $seq ),
            };
        }
        else {
            die "$seq_line doesn't match $bed_line!";
        }
    }


    return \%alignments;
}

=head2 calculate_percent_alignment

Calculate the percentage hit a aligment has

=cut
sub calculate_percent_alignment {
    my ( $self, $name, $alignment_seq ) = @_;
    my $oligo_seq = $self->get_oligo_seq( $name );
    my $oligo_length = length( $oligo_seq );
    my $hamming_distance = hamming_distance( $alignment_seq, $oligo_seq );

    my $percent_hit = 100 * ( ( $oligo_length - $hamming_distance ) / $oligo_length );
    return sprintf("%.0f", $percent_hit);
}

=head2 hamming_distance

use string xor to get the number of mismatches between the two strings.
the xor returns a string with the binary digits of each char xor'd,
which will be an ascii char between 001 and 255. tr returns the number of characters replaced.

=cut
sub hamming_distance {
    die "Strings passed to hamming distance differ" if length($_[0]) != length($_[1]);
    return (uc($_[0]) ^ uc($_[1])) =~ tr/\001-\255//;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
