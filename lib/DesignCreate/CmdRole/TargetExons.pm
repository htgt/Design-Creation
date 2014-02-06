package DesignCreate::CmdRole::TargetExons;

=head1 NAME

DesignCreate::Action::TargetExons - target region coordinates for exon(s)

=head1 DESCRIPTION

For given exon id(s) calculate target region coordinates for design.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt Strand Chromosome Species );
use DesignCreate::Constants qw( $DEFAULT_TARGET_COORD_FILE_NAME %CURRENT_ASSEMBLY );
use YAML::Any qw( DumpFile );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

const my @DESIGN_PARAMETERS => qw(
species
assembly
target_genes
five_prime_exon
three_prime_exon
target_start
target_end
chr_name
chr_strand
);

has five_prime_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id for five prime exon, if targeting only one exon use this',
    required      => 1,
    cmd_flag      => 'five-prime-exon',
    cmd_aliases   => 'target-exon', # keep old name as legacy
);

has three_prime_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id for last exon, only used if specifying range of exons to target',
    cmd_flag      => 'three-prime-exon',
);

has target_genes => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt' ],
    documentation => 'Name of target gene(s) of design',
    required      => 1,
    cmd_flag      => 'target-gene',
);

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target ( Mouse or Human )',
    required      => 1,
);

has assembly => (
    is         => 'ro',
    isa        => 'Str',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_assembly {
    my $self = shift;

    return $CURRENT_ASSEMBLY{ $self->species };
}

has target_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has target_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has chr_name => (
    is         => 'rw',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
);

has chr_strand => (
    is         => 'rw',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
);

=head2 target_coordinates

Output target yaml file, with following information:
chromosome
strand
start
end

=cut
sub target_coordinates {
    my ( $self, $opts, $args ) = @_;

    $self->calculate_target_region_coordinates;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->create_target_coordinate_file;

    return;
}

=head2 calculate_target_region_coordinates

Calculate following values given the target exon(s):
target_start
target_end
chr_strand
chr_name

=cut
sub calculate_target_region_coordinates {
    my $self = shift;

    $self->log->info( 'Calculating target coordinates for exon(s)' );
    my $five_prime_exon = $self->build_exon( $self->five_prime_exon );
    $self->chr_name( $five_prime_exon->seq_region_name ) unless $self->chr_name;
    $self->chr_strand( $five_prime_exon->strand ) unless $self->chr_strand;

    my $three_prime_exon
        = $self->three_prime_exon ? $self->build_exon( $self->three_prime_exon ) : undef;

    # if there is no three prime exon then just specify target start and end
    # as the start and end of the five prime exon
    unless ( $three_prime_exon ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
        return;
    }

    $self->validate_exon_targets( $five_prime_exon, $three_prime_exon );

    if ( $self->chr_strand == 1 ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $three_prime_exon->seq_region_end );
    }
    else {
        $self->target_start( $three_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
    }

    return;
}

=head2 validate_exon_targets

Check exons are both on the same gene.
Check the five prime exon is before the three prime exon.

=cut
sub validate_exon_targets {
    my ( $self, $five_prime_exon, $three_prime_exon ) = @_;

    my $five_prime_exon_gene  = $self->gene_adaptor->fetch_by_exon_stable_id( $five_prime_exon->stable_id );
    my $three_prime_exon_gene = $self->gene_adaptor->fetch_by_exon_stable_id( $three_prime_exon->stable_id );

    DesignCreate::Exception->throw(
        'Exon mismatch,'
        . ' five prime exon '      . $five_prime_exon->stable_id
        . ' is linked to gene '    . $five_prime_exon_gene->stable_id
        . ' BUT three prime exon ' . $three_prime_exon->stable_id
        . ' is linked to gene  '   . $three_prime_exon_gene->stable_id
    ) if $five_prime_exon_gene->stable_id ne $three_prime_exon_gene->stable_id;

    if ( $self->chr_strand == 1 ) {
        DesignCreate::Exception->throw(
            'On +ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is after the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start > $three_prime_exon->seq_region_start;
    }
    else {
        DesignCreate::Exception->throw(
            'On -ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is before the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start < $three_prime_exon->seq_region_start;
    }

    $self->log->debug('We have valid exon targets');

    return;
}

=head2 build_exon

Grab a Bio::Ensembl::Exon object given a exon stable id.
Make sure exon object is in teh chromosome coordinate system.

=cut
sub build_exon {
    my ( $self, $exon_id ) = @_;
    my $exon;

    try{
        $exon = $self->exon_adaptor->fetch_by_stable_id( $exon_id );
    };

    unless ( $exon ) {
        DesignCreate::Exception->throw(
            'Unable to retrieve exon: ' . $exon_id );
    }

    # check exon is on the chromosome coordinate system
    if ( $exon->coord_system_name ne 'chromosome' ) {
        $exon = $exon->transform( 'chromosome' );
    }

    return $exon;
}

=head2 create_target_coordinate_file

Create yaml file with target information

=cut
sub create_target_coordinate_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( $DEFAULT_TARGET_COORD_FILE_NAME );
    DumpFile(
        $file,
        {   target_start => $self->target_start,
            target_end   => $self->target_end,
            chr_name     => $self->chr_name,
            chr_strand   => $self->chr_strand,
        }
    );
    $self->log->debug('Created target coordinates file');

    return;
}


1;

__END__
