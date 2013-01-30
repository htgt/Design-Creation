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
use Const::Fast;
use namespace::autoclean;

extends qw( DesignCreate::Action );

#TODO install AOS in sensible place and change this
const my $DEFAULT_AOS_LOCATION => '/nfs/users/nfs_s/sp12/workspace/ArrayOligoSelector';

has aos_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_aos_dir {
    my $self = shift;

    my $aos_dir = $self->dir->subdir('aos')->absolute;
    $aos_dir->mkpath();

    return $aos_dir;
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

has aos_location => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    default       => sub{ Path::Class::Dir->new( $DEFAULT_AOS_LOCATION )->absolute },
    documentation => "Location of AOS scripts ( default $DEFAULT_AOS_LOCATION )",
    cmd_flag      => 'aos-location'
);

has oligo_length => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Length of the oligos AOS is to find ( default 50 )',
    default       => 50,
    cmd_flag      => 'oligo-length',
);

has num_oligos => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Number of oligos AOS finds for each query sequence ( default 3 )',
    default       => 3,
    cmd_flag      => 'num-oligos',
);

has minimum_gc_content => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Minumum GC content of oligos ( default 28 )',
    default       => 28,
    cmd_flag      => 'min-gc-content',
);

has mask_by_lower_case => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Should AOS mask lowercase sequence in its calculations ( default no )',
    default       => 'no',
    cmd_flag      => 'mask-by-lower-case',
);

has genomic_search_method => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Method AOS uses to identify genomic origin, options: blat or blast ( default blat )',
    default       => 'blat',
    cmd_flag      => 'genomic-search-method',
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    chdir $self->aos_dir->stringify;

    system('ln -s ' . $self->aos_location->stringify . '/*' . ' .');

    #TODO not in vm, can i use /software/bin/blastall? using blastall that came with AOS at the moment
    #system("ln -s /usr/local/ensembl/bin/blastall ./code/blastall");

    $self->run_aos_script1;
    $self->run_aos_script2;

}

sub run_aos_script1 {
    my $self = shift;

    # have to make symlinks because aos likes to make a mess by creating
    # new files in the directory of both and query and target fasta files
    system('ln -s ' . $self->query_file->stringify . ' ./query.fa');
    system('ln -s ' . $self->target_file->stringify . ' ./target.fa');

    my @step1_args = (
        './query.fa',
        './target.fa',
        $self->oligo_length,
        $self->mask_by_lower_case,
        $self->genomic_search_method,
    );

    $self->log->info('Running AOS script1');
    system( './Pick70_script1_contig', @step1_args );
}

sub run_aos_script2 {
    my $self = shift;

    my @step2_args = (
        $self->minimum_gc_content,
        $self->oligo_length,
        $self->num_oligos,
    );

    $self->log->info('Running AOS script2');
    system( './Pick70_script2', @step2_args );
}

# AFTER RUNNING AOS
# check oligo_fasta file exists
# read the file into bioseqio obj
# iterate through bioseqio object and push sequence into hash keyed on display id 
# maybe now put into yaml file?


__PACKAGE__->meta->make_immutable;

1;

__END__
