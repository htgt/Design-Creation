package DesignCreate::Action::RunAOS;

=head1 NAME

DesignCreate::Action::RunAOS - A wrapper around AOS

=head1 DESCRIPTION

Wrapper around AOS ( ArrayOligoSelector ).

AOS Inputs:

Files: ( fasta )
Query Sequence file
Target Sequence file

Parameters:
Minimum GC content
Oligo Length
Number of Oligos
Mask by lower case? - yes / no
Method to identify genomic origin - blat / blast / gfclient

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use IPC::System::Simple qw( system );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Bio::SeqIO;
use YAML::Any qw( DumpFile );
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::Role::AOSParameters';

#TODO install AOS in sensible place and change this

has aos_work_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_aos_work_dir {
    my $self = shift;

    my $aos_work_dir = $self->dir->subdir('aos_work')->absolute;
    $aos_work_dir->mkpath();

    return $aos_work_dir;
}

has aos_output_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_aos_output_dir {
    my $self = shift;

    my $aos_output_dir = $self->dir->subdir('aos_output')->absolute;
    $aos_output_dir->mkpath();

    return $aos_output_dir;
}

has query_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    required      => 1,
    documentation => 'The fasta file containing the query sequence',
    cmd_flag      => 'query-file'
);

has target_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    required      => 1,
    documentation => 'The fasta file containing the target sequence',
    cmd_flag      => 'target-file'
);

has oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt', 'Hash' ],
    default => sub { {  } },
    handles => {
        has_oligos => 'count',
        add_oligo  => 'set',
        get_oligos => 'get',
    }
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->run_aos;

    $self->parse_aos_output;

    $self->create_oligo_files;

    return;
}

sub run_aos {
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
    system( @step1_cmd );

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
    system( @step2_cmd );

    return;
}

sub parse_aos_output {
    my $self = shift;
    $self->log->info('Parsing AOS output');

    unless ( $self->aos_work_dir->contains( 'oligo_fasta' ) ) {
        $self->log->error( 'Can not find oligo_fasta output file from aos' );
        return;
    }

    my $oligos_file = $self->aos_work_dir->file( 'oligo_fasta' );
    my $seq_in = Bio::SeqIO->new( -fh => $oligos_file->openr, -format => 'fasta' );

    while ( my $seq = $seq_in->next_seq ) {
        $self->log->debug('Parsing: ' . $seq->display_id );
        $self->parse_oligo_seq( $seq );
    }

    return;
}

sub parse_oligo_seq {
    my ( $self, $seq ) = @_;
    my %oligo_data;

    unless ( $seq->display_id =~ /^(U|D|G)(3|5):\d+-\d+_\d+$/ ) {
        $self->log->warn(
            'Oligo sequence display id is not in expected format: ' . $seq->display_id );
        $seq->display_id =~ /^(.*)_(\d+)$/;
        push @{ $self->oligos->{$1} },
            { seq => $seq->seq, display_id => $seq->display_id, offset => $2 };

        return;
    }

    my ( $oligo, $location )        = split( ':', $seq->display_id );
    my ( $coordinates, $offset )    = split( '_', $location );
    my ( $query_start, $query_end ) = split( '-', $coordinates );

    $oligo_data{target_region_start} = $query_start + 0;
    $oligo_data{target_region_end}   = $query_end + 0;

    $oligo_data{oligo_start}  = $query_start + $offset;
    $oligo_data{oligo_end}    = $oligo_data{oligo_start} + ( $self->oligo_length - 1 );
    $oligo_data{oligo_length} = $self->oligo_length;
    $oligo_data{oligo_seq}    = $seq->seq;
    $oligo_data{offset}       = $offset;
    $oligo_data{oligo}        = $oligo;

    push @{ $self->oligos->{$oligo} }, \%oligo_data;

    return;
}

sub create_oligo_files {
    my $self = shift;
    $self->log->info('Creating oligo output files');

    unless ( $self->has_oligos ) {
        $self->log->error( 'No oligos found' );
        return;
    }

    for my $oligo ( keys %{ $self->oligos } ) {
        my $filename = $self->aos_output_dir->stringify . '/' . $oligo . '.yaml';
        DumpFile( $filename, $self->get_oligos( $oligo ) );
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
