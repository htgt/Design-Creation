package DesignCreate::Util::BWA;

=head1 NAME

DesignCreate::Util::BWA

=head1 DESCRIPTION

Align sequence(s) against a genome to find number of hits using BWA

=cut

use Moose;
use DesignCreate::Exception;
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
    my $self = shift;

    return $self->work_dir->file('query.sam')->absolute;
}

use Smart::Comments;
sub run_bwa_checks {
    my $self = shift;

    $self->run_bwa;
    $self->generate_bed_files;
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
    run( \@aln_command, '<', \undef, '>', $bwa_aln_file->stringify, '2>', $bwa_aln_log_file->stringify )
        or DesignCreate::Exception->throw(
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

    my $bwa_samse_file = $self->work_dir->file('query.sam')->absolute;
    my $bwa_samse_log_file = $self->work_dir->file( 'bwa_samse.log' )->absolute;
    run( \@samse_command, '<', \undef, '>', $bwa_samse_file->stringify, '2>', $bwa_samse_log_file->stringify )
        or DesignCreate::Exception->throw(
            "Failed to run bwa samse command, see log file: $bwa_samse_log_file" );

    return;
}

=head2 generate_bed_files

Take sam file output from bwa and generate sorted bed files.

=cut
sub generate_bed_files {
    my ( $self  ) = @_;
    # /software/solexa/bin/aligners/bwa/current/xa2multi.pl [test-oligos.sam]
    # | /software/solexa/bin/samtools view -bS -
    # | /software/solexa/bin/samtools sort - [test-oligos.sorted]

    my @xa2multi_command = (
        $XA2MULTI_CMD,
        'view',                         # align command 
    );
    
    my @view_command = (
        $SAMTOOLS_CMD,
        'view',                         # align command 
    );

    my @sort_command = (
        $SAMTOOLS_CMD,
        'sort',                         # align command 
    );
}

__PACKAGE__->meta->make_immutable;

1;

__END__
