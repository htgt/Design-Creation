package DesignCreate::Action::ConsolidateDesignData;

=head1 NAME

DesignCreate::Action::ConsolidateDesignData - Bring together all the design data into one file

=head1 DESCRIPTION

Create one yaml file containing all the data for one design:
Target
Species
Phase
Design Type
Created By
Oligos

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use DesignCreate::Types qw( Species Strand Chromosome );
use Const::Fast;
use YAML::Any qw( LoadFile DumpFile );
use Data::Dump qw( pp );
use namespace::autoclean;

extends qw( DesignCreate::Action );

const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';

has target_genes => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt' ],
    documentation => 'The name of the target gene(s) of the design',
    required      => 1,
    cmd_flag      => 'target-gene',
);

has created_by => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Name of user who created design, must be valid LIMS2 user, default is: system',
    default       => 'system',
    cmd_flag      => 'created-by',
);

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target, default is: mouse',
    default       => 'mouse',
);

has assembly => (
    is       => 'ro',
    isa      => 'Str',
    traits   => [ 'Getopt' ],
    default  => 'GRCm38'
);

has chr_name => (
    is            => 'ro',
    isa           => Chromosome,
    traits        => [ 'Getopt' ],
    documentation => 'Name of chromosome the design target lies within',
    required      => 1,
    cmd_flag      => 'chromosome'
);

has chr_strand => (
    is            => 'ro',
    isa           => Strand,
    traits        => [ 'Getopt' ],
    documentation => 'The strand the design target lies on',
    required      => 1,
    cmd_flag      => 'strand'
);

has validated_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the validated oligos, '
                     . " defaults to [design_dir]/$DEFAULT_VALIDATED_OLIGO_DIR_NAME",
    coerce        => 1,
    cmd_flag      => 'validated-oligo-dir',
    lazy_build    => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME );
    unless ( $self->dir->contains( $validated_oligo_dir ) ) {
        $self->log->logdie( "Can't find validated oligo file dir: "
                           . $self->validated_oligo_dir->stringify );
    }

    return $validated_oligo_dir->absolute;
}

has gap_oligo_pair => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);

sub _build_gap_oligo_pair {
    my $self = shift;

    my $gap_oligo_pair_file = $self->validated_oligo_dir->file( 'gap_oligo_pairs.yaml' );

    my $gap_oligos = LoadFile( $gap_oligo_pair_file );
    unless ( @{ $gap_oligos } ) {
        $self->log->logdie( "No gap oligo data in $gap_oligo_pair_file" );
    }

    return shift @{ $gap_oligos };
}

has phase => (
    is     => 'rw',
    isa    => 'Int',
    traits => [ 'NoGetopt' ],
);

has oligos => (
    is     => 'rw',
    isa    => 'ArrayRef',
    traits => [ 'NoGetopt' ],
);

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->get_design_phase;
    $self->build_oligo_array;
    $self->create_design_file;

    return;
}

#TODO work out phase for design
sub get_design_phase {
    my $self = shift;

    $self->log->warn( 'Code to work out design phase not in place, setting it to -1 for now' );
    $self->phase( -1 );

    return;
}

sub build_oligo_array {
    my $self = shift;
    my @oligos;

    $self->log->info('Picking out design oligos');
    for my $oligo_type ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->validated_oligo_dir->file( $oligo_type . '.yaml' );
        unless ( $self->validated_oligo_dir->contains( $oligo_file ) ) {
            $self->log->error("Can't find $oligo_type oligo file: $oligo_file");
            return;
        }
        my $oligos = LoadFile( $oligo_file );

        push @oligos, $self->get_oligo( $oligos, $oligo_type );
    }

    $self->oligos( \@oligos );

    return;
}

sub get_oligo {
    my ( $self, $oligos, $oligo_type ) = @_;
    my $oligo;

    if ( $oligo_type =~ /^G(5|3)$/ ) {
        my $gap_oligo_id = $self->gap_oligo_pair->{$oligo_type};
        ( $oligo ) = grep{ $_->{id} eq $gap_oligo_id } @{ $oligos };
    }
    else {
        $oligo = shift @{ $oligos };
    }

    return $self->format_oligo_data( $oligo );
}

sub format_oligo_data {
    my ( $self, $oligo ) = @_;

    return {
        type => $oligo->{oligo},
        seq  => $oligo->{oligo_seq},
        loci => [
            {
                assembly   => $self->assembly,
                chr_start  => $oligo->{oligo_start},
                chr_end    => $oligo->{oligo_end},
                chr_name   => $self->chr_name,
                chr_strand => $self->chr_strand,
            }
        ]
    };
}

sub create_design_file {
    my $self = shift;

    my %design_data = (
        type       => $self->design_method,
        species    => $self->species,
        gene_ids   => $self->target_genes,
        phase      => $self->phase,
        created_by => $self->created_by,
        oligos     => $self->oligos,
    );
    $self->log->debug( 'Design Data: ' . pp(%design_data) );

    my $design_data_file = $self->dir->file('design_data.yaml');
    $self->log->info( "Creating design file: $design_data_file" );
    DumpFile( $design_data_file, \%design_data );

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
