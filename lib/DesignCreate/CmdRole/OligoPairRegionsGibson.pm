package DesignCreate::CmdRole::OligoPairRegionsGibson;

=head1 NAME

DesignCreate::Action::OligoPairRegionsGibson -

=head1 DESCRIPTION


=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt Strand DesignMethod Chromosome );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::EnsEMBL
DesignCreate::Role::OligoRegionCoordinates
);

const my @DESIGN_PARAMETERS => qw(
design_method
species
assembly
target_genes
target_exon
target_start
target_end
chr_name
chr_strand
offset_ef
size_ef
offset_er
size_er
offset_5f
size_5f
offset_5r
size_5r
offset_3f
size_3f
offset_3r
size_3r
);

has [
    qw(
        offset_ef
        size_ef
        offset_er
        size_er
        offset_5f
        size_5f
        offset_5r
        size_5r
        offset_3f
        size_3f
        offset_3r
        size_3r
    )
] => (
    is       => 'ro',
    isa      => PositiveInt,
    traits   => [ 'Getopt' ],
    required => 1,
);

#for my $name ( @GIBSON_PARAMETERS )  {
    #my $cmd_flag =

    #has $name => (
        #is       => 'ro',
        #isa      => PositiveInt,
        #traits   => [ 'Getopt' ],
        #required => 1,
        #documentation =>
        #cmd_flag =>
    #);
#}

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'gibson'
);

has target_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id we are targeting',
    required      => 1,
    cmd_flag      => 'target-exon'
);

has exon => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Exon',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon {
    my $self = shift;

    my $exon = try{ $self->exon_adaptor->fetch_by_stable_id( $self->target_exon ) };
    unless ( $exon ) {
        DesignCreate::Exception->throw( 'Unable to retrieve exon ' . $self->target_exon);
    }

    # check exon is on the chromosome coordinate system
    if ( $exon->coord_system_name ne 'chromosome' ) {
        $exon = $exon->transform( 'chromosome' );
    }

    return $exon;
}

has target_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
 );

sub _build_target_start {
    shift->exon->seq_region_start;
}

has target_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_end {
    shift->exon->seq_region_end;
}

has chr_name => (
    is         => 'ro',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_name {
    shift->exon->seq_region_name;
}

has chr_strand => (
    is         => 'ro',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_strand {
    shift->exon->strand;
}

# primer3 expects sequence in a 5' to 3' direction
has exon_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

has exon_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->target_start - ( $self->offset_ef + $self->size_ef );
    }
    else {
        $start = $self->target_start - ( $self->offset_er + $self->size_er );
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has exon_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->target_end + ( $self->offset_er + $self->size_er );
    }
    else {
        $end = $self->target_end + ( $self->offset_ef + $self->size_ef );
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

has five_prime_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->target_start - ( $self->offset_5f + $self->size_5f );
    }
    else {
        $start = $self->target_end + $self->offset_5r;
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has five_prime_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->target_start - $self->offset_5r;
    }
    else {
        $end = $self->target_end + ( $self->offset_5f + $self->size_5f );
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

has three_prime_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->target_end + $self->offset_3f;
    }
    else {
        $start = $self->target_start - ( $self->offset_3r + $self->size_3r );
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has three_prime_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->target_end + ( $self->offset_3r + $self->size_3r );
    }
    else {
        $end = $self->target_start - $self->offset_3f;
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

=head2 get_oligo_pair_region_coordinates

blah

=cut
sub get_oligo_pair_region_coordinates {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    #TODO check coordinates sp12 Thu 25 Jul 2013 11:21:58 BST
    # EF offset + ef size = 5r offset - 1 ???
    # or maybe check for overlaps

    for my $region ( qw( exon five_prime three_prime ) ) {
        my $start_attr_name = $region . '_region_start';
        my $end_attr_name = $region . '_region_end';
        $self->oligo_region_coordinates->{ $region } = {
            start => $self->$start_attr_name,
            end => $self->$end_attr_name
        };
    }

    # in Role::OligoRegionCoordinates
    $self->create_oligo_region_coordinate_file;

    return;
}

1;

__END__
