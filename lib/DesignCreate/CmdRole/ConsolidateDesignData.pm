package DesignCreate::CmdRole::ConsolidateDesignData;

=head1 NAME

DesignCreate::CmdRole::ConsolidateDesignData - Bring together all the design data into one file

=head1 DESCRIPTION

Create one yaml file containing all the data for one design:
Target
Species
Phase
Design Type
Created By
Oligos

=cut

use Moose::Role;
use YAML::Any qw( LoadFile DumpFile );
use Data::Dump qw( pp );
use namespace::autoclean;

with qw(
DesignCreate::Role::Chromosome
DesignCreate::Role::Oligos
);

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
    documentation => 'Name of user who created design, must be valid LIMS2 user ( default system )',
    default       => 'system',
    cmd_flag      => 'created-by',
);

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

has picked_oligos => (
    is     => 'rw',
    isa    => 'ArrayRef',
    traits => [ 'NoGetopt' ],
);

sub consolidate_design_data {
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

    $self->picked_oligos( \@oligos );

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
        oligos     => $self->picked_oligos,
    );
    $self->log->debug( 'Design Data: ' . pp(%design_data) );

    #TODO make name of file a constant
    my $design_data_file = $self->dir->file('design_data.yaml');
    $self->log->info( "Creating design file: $design_data_file" );
    DumpFile( $design_data_file, \%design_data );

    return;
}

1;

__END__
