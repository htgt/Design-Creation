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

use Smart::Comments;
sub run_bwa_checks {
    my $self = shift;

    $self->run_bwa;
    $self->generate_bam_files;
    $self->parse_bam_file;
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
    $self->log->info( 'Generate sorted bam files' );

    my @xa2multi_command = (
        $XA2MULTI_CMD,
        $self->sam_file->stringify,
    );
    $self->log->debug( "xa2multi command: " . join( ' ', @xa2multi_command ) );

    my $xa2multi_file = $self->work_dir->file('query.multi.sam')->absolute;
    my $xa2multi_log_file = $self->work_dir->file('xa2multi.log')->absolute;
    run( \@xa2multi_command,
        '<', \undef,
        '>', $xa2multi_file->stringify,
        '2>', $xa2multi_log_file->stringify
    ) or DesignCreate::Exception->throw(
            "Failed to run xa2multi command, see log file: $xa2multi_log_file" );

    my @view_command = (
        $SAMTOOLS_CMD,
        'view',                    #
        '-bS',                     #
        $xa2multi_file->stringify,
    );
    $self->log->debug( "samtools view command: " . join( ' ', @view_command ) );

    my $samtools_view_file = $self->work_dir->file('query.bam')->absolute;
    my $samtools_view_log_file = $self->work_dir->file('samtools_view.log')->absolute;
    run( \@view_command,
        '<', \undef,
        '>', $samtools_view_file->stringify,
        '2>', $samtools_view_log_file->stringify
    ) or DesignCreate::Exception->throw(
            "Failed to run xa2multi command, see log file: $samtools_view_log_file" );

    my $samtools_sort_file = $self->work_dir->file('query.sorted')->absolute;
    my @sort_command = (
        $SAMTOOLS_CMD,
        'sort',                         #
        $samtools_view_file->stringify,
        $samtools_sort_file->stringify,
    );
    $self->log->debug( "samtools sort command: " . join( ' ', @sort_command ) );

    my $samtools_sort_log_file = $self->work_dir->file('samtools_sort.log')->absolute;
    run( \@sort_command,
        '<', \undef,
        '&>', $samtools_sort_log_file->stringify
    ) or DesignCreate::Exception->throw(
            "Failed to run samtools sort command, see log file: $samtools_sort_log_file" );

    # TODO cleanup surplus files if we are successful
    $xa2multi_log_file->remove;
    $samtools_view_log_file->remove;
    $samtools_sort_log_file->remove;
    $samtools_view_file->remove;
}

=head2 parse_bam_file

Parse sorted bam files into output we can use.
Need to grab sequence of alignment.

=cut
sub parse_bam_file {
    my ( $self  ) = @_;
    # bamToBed -i [test-oligos.sorted.bam] > [test-oligos.bed]

}


__PACKAGE__->meta->make_immutable;

1;

__END__
