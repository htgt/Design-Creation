package DesignCreate::Role::AOS;

=head1 NAME

DesignCreate::Role::AOS

=head1 DESCRIPTION

Role for running AOS, anything that consumes this role should provide these attributes:
query_file
target_file

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt YesNo AOSSearchMethod );
use Const::Fast;
use IPC::System::Simple qw( system );
use IPC::Run qw( run );
use Bio::SeqIO;
use YAML::Any qw( DumpFile );
use Fcntl; # O_ constants
use Try::Tiny;
use namespace::autoclean;

requires 'oligo_finder_output_dir';
# TODO
# also required query_file and target_file attribute but errors are thrown when this is added

#TODO install AOS in sensible place and change this
const my $DEFAULT_AOS_LOCATION => $ENV{AOS_LOCATION}
    || '/nfs/users/nfs_s/sp12/workspace/ArrayOligoSelector';
const my $DEFAULT_AOS_WORK_DIR_NAME   => 'aos_work';

has aos_location => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    default       => sub{ Path::Class::Dir->new( $DEFAULT_AOS_LOCATION )->absolute },
    documentation => "Location of AOS scripts ( default $DEFAULT_AOS_LOCATION )",
    cmd_flag      => 'aos-location'
);

has aos_work_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'NoGetopt' ],
    lazy_build    => 1,
);

sub _build_aos_work_dir {
    my $self = shift;

    my $aos_work_dir = $self->dir->subdir( $DEFAULT_AOS_WORK_DIR_NAME )->absolute;
    $aos_work_dir->rmtree();
    $aos_work_dir->mkpath();

    return $aos_work_dir;
}

has oligo_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Length of the oligos AOS is to find ( default 50 )',
    default       => 50,
    cmd_flag      => 'oligo-length',
);

has num_oligos => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Number of oligos AOS finds for each query sequence ( default 3 )',
    default       => 3,
    cmd_flag      => 'num-oligos',
);

has minimum_gc_content => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Minumum GC content of oligos ( default 28 )',
    default       => 28,
    cmd_flag      => 'min-gc-content',
);

has mask_by_lower_case => (
    is            => 'ro',
    isa           => YesNo,
    traits        => [ 'Getopt' ],
    documentation => 'Should AOS mask lowercase sequence in its calculations ( default yes )',
    default       => 'yes',
    cmd_flag      => 'mask-by-lower-case',
);

has genomic_search_method => (
    is            => 'ro',
    isa           => AOSSearchMethod,
    traits        => [ 'Getopt' ],
    documentation => 'Method AOS uses to identify genomic origin, options: blat or blast ( default blat )',
    default       => 'blat',
    cmd_flag      => 'genomic-search-method',
);

has oligo_count => (
    is      => 'ro',
    isa     => 'Num',
    default => 0,
    traits  => [ 'NoGetopt', 'Counter' ],
    handles => {
        inc_oligo_count => 'inc',
    }
);

has aos_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt', 'Hash' ],
    default => sub { {  } },
    handles => {
        has_oligos => 'count',
        get_oligos => 'get',
    }
);

sub run_aos {
    my $self = shift;

    try{
        $self->run_aos_scripts;
        $self->parse_aos_output;
        $self->create_oligo_files;
    }
    catch {
        DesignCreate::Exception->throw( 'Problem running AOS wrapper, check log files in this dir: '
            . $self->oligo_finder_output_dir->stringify );
    };

    return;
}

sub run_aos_scripts {
    my $self = shift;
    $self->log->info('Setting up to run AOS');

    # AOS scripts need to be called from within its home directory
    # Also produces lots of output files within this directory so we symlink the
    # entire AOS home directory to keep output contained in one working directory
    chdir $self->aos_work_dir->stringify;
    system('ln -s ' . $self->aos_location->stringify . '/*' . ' .');

    #TODO not in vm, can i use /software/bin/blastall? using blastall that came with AOS at the moment
    #system("ln -s /usr/local/ensembl/bin/blastall ./code/blastall");

    $self->run_aos_script1;
    $self->run_aos_script2;

    #unless we have this oligo_fasta file then something went wrong
    my $oligo_fasta_aos = $self->get_file( "oligo_fasta", $self->aos_work_dir );

    #oligo_fasta file should have some data in it
    unless ( $oligo_fasta_aos->slurp ) {
        DesignCreate::Exception->throw( "AOS oligo_fasta file has no data in it"
            . $self->aos_work_dir->stringify  );
    }

    return;
}

sub run_aos_script1 {
    my $self = shift;
    $self->log->info('Running AOS script1');

    # have to make symlinks because aos likes to make a mess by creating
    # new files in the directory of both and query and target fasta files
    system('ln -s ' . $self->query_file->stringify . ' ./query.fa');
    system('ln -s ' . $self->target_file->stringify . ' ./target.fa');

    my @step1_cmd = (
        './Pick70_script1_contig',
        './query.fa',
        './target.fa',
        $self->oligo_length,
        $self->mask_by_lower_case,
        $self->genomic_search_method,
    );

    $self->log->debug('AOS script1 cmd: ' . join( ' ', @step1_cmd ) );
    my $output_log = $self->oligo_finder_output_dir->file( 'script1_output.log' );
    my $output_log_fh = $output_log->open( O_WRONLY|O_CREAT ) or die( "Open $output_log: $!" );

    # run script and redirect STDOUT and STDERR to log file
    run( \@step1_cmd, '<', \undef, '>&', $output_log_fh )
        or DesignCreate::Exception->throw(
            "Failed to run AOS script Pick70_script1_contig, check $output_log log file for details" );

    # this file takes up a lot of space, remove it
    try{ system('rm target.fa.nsq') };

    return;
}

sub run_aos_script2 {
    my $self = shift;
    $self->log->info('Running AOS script2');

    my @step2_cmd = (
        './Pick70_script2',
        $self->minimum_gc_content,
        $self->oligo_length,
        $self->num_oligos,
    );

    $self->log->debug('AOS script2 cmd: ' . join( ' ', @step2_cmd ) );
    my $output_log = $self->oligo_finder_output_dir->file( 'script2_output.log' );
    my $output_log_fh = $output_log->open( O_WRONLY|O_CREAT ) or die( "Open $output_log: $!" );

    # run script and redirect STDOUT and STDERR to log file
    run( \@step2_cmd, '<', \undef, '>&', $output_log_fh )
        or DesignCreate::Exception->throw(
            "Failed to run AOS script Pick70_script2, check $output_log log file for details" );

    return;
}

sub parse_aos_output {
    my $self = shift;
    $self->log->info('Parsing AOS output');

    my $oligos_file = $self->aos_work_dir->file( 'oligo_fasta' );
    my $seq_in = Bio::SeqIO->new( -fh => $oligos_file->openr, -format => 'fasta' );

    while ( my $seq = $seq_in->next_seq ) {
        $self->inc_oligo_count;
        $self->log->debug('Parsing: ' . $seq->display_id );
        my $oligo_data = $self->parse_oligo_seq( $seq );
        next unless $oligo_data;
        push @{ $self->aos_oligos->{ $oligo_data->{oligo} } }, $oligo_data;
    }

    return;
}

## no critic(RegularExpressions::ProhibitComplexRegexes)
sub parse_oligo_seq {
    my ( $self, $seq ) = @_;
    my %oligo_data;

    my $oligo_id_regex = qr/
        ^
        (?<oligo>(U|D|G)(3|5))
        :
        (?<start>\d+)
        -
        (?<end>\d+)
        _
        (?<offset>\d+)
        $
    /x;

    unless ( $seq->display_id =~ $oligo_id_regex ) {
        $self->log->warn(
            'Oligo sequence display id is not in expected format: ' . $seq->display_id );
        return;
    }

    $oligo_data{target_region_start} = $+{start} + 0;
    $oligo_data{target_region_end}   = $+{end} + 0;

    $oligo_data{oligo_start}  = $+{start} + $+{offset};
    $oligo_data{oligo_end}    = $oligo_data{oligo_start} + ( $self->oligo_length - 1 );
    $oligo_data{oligo_length} = $self->oligo_length;
    $oligo_data{oligo_seq}    = $seq->seq;
    $oligo_data{offset}       = $+{offset} + 0;
    $oligo_data{oligo}        = $+{oligo};
    $oligo_data{id}           = $+{oligo} . '-' . $self->oligo_count;

    return \%oligo_data;
}
## use critic

sub create_oligo_files {
    my $self = shift;
    $self->log->info('Creating oligo output files');

    DesignCreate::Exception->throw( 'No oligos found' )
        unless $self->has_oligos;

    for my $oligo ( keys %{ $self->aos_oligos } ) {
        my $filename = $self->oligo_finder_output_dir->stringify . '/' . $oligo . '.yaml';
        DumpFile( $filename, $self->get_oligos( $oligo ) );
    }

    return;
}

1;

__END__
