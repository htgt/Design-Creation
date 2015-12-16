package DesignCreate::CmdRole::TargetCurrentDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::TargetCurrentDesign::VERSION = '0.039';
}
## use critic


=head1 NAME

DesignCreate::Action::TargetCurrentDesign - target region of existing design we want to modify

=head1 DESCRIPTION

Take a current design and base the target region around that.
We will use the U5 / D3 oligo coordiantes for this.

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
target_start
target_end
chr_name
chr_strand
original_design_id
);

has original_design_id => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'LIMS2 id of design you wish to modify',
    cmd_flag      => 'design-id',
);

has original_design_data => (
    is         => 'rw',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

=head2 _build_original_design_data

Grab design data from LIMS2 and store in a hash as well as yaml file.

=cut
sub _build_original_design_data {
    my $self = shift;

    $self->log->debug('Grabbing design info from LIMS2 for design: ' . $self->original_design_id );
    my $design_data = try{ $self->lims2_api->GET( 'design', { id => $self->original_design_id } ) };

    unless ( $design_data ) {
        $self->log->error( 'DESIGN INCOMPLETE: Unable to find design in LIMS2 ' . $self->original_design_id );
        DesignCreate::Exception->throw( "Can not find LIMS2 design: " . $self->original_design_id )
    }

    my $file = $self->dir->file( 'original_lims2_design.yaml' );
    DumpFile( $file, $design_data );
    $self->log->debug('Created original design data file');

    return $design_data;
}

has original_design_oligos => (
    is         => 'rw',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_original_design_oligos {
    my $self = shift;

    my %oligo_data = map{ $_->{type} => $_  } @{ $self->original_design_data->{oligos} };

    return \%oligo_data;
}

has target_genes => (
    is         => 'ro',
    isa        => 'ArrayRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_genes {
    my $self = shift;

    return $self->original_design_data->{assigned_genes};
}

has species => (
    is         => 'ro',
    isa        => Species,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_species {
    my $self = shift;

    return $self->original_design_data->{species};
}

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
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_start {
    my $self = shift;

    my $target_start;
    if ( $self->chr_strand == 1 ) {
        $target_start = $self->original_design_oligos->{U5}{locus}{chr_start};
    }
    else {
        $target_start = $self->original_design_oligos->{D3}{locus}{chr_start};
    }

    return $target_start;
}

has target_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_end {
    my $self = shift;

    my $target_end;
    if ( $self->chr_strand == 1 ) {
        $target_end = $self->original_design_oligos->{D3}{locus}{chr_end};
    }
    else {
        $target_end = $self->original_design_oligos->{U5}{locus}{chr_end};
    }

    return $target_end;
}

has chr_name => (
    is         => 'ro',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_name {
    my $self = shift;

    return $self->original_design_oligos->{U5}{locus}{chr_name};
}

has chr_strand => (
    is         => 'ro',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_strand {
    my $self = shift;

    return $self->original_design_oligos->{U5}{locus}{chr_strand};
}

=head2 target_coordinates

Output target yaml file, with following information:
chromosome
strand
start
end

=cut
sub target_coordinates {
    my ( $self, $opts, $args ) = @_;

    $self->verify_target_coordinates;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->create_target_coordinate_file;
    $self->log->info('Calculate target coordiantes from LIMS2 design: ' . $self->original_design_id );

    return;
}

=head2 verify_target_coordinates

Verify user supplied target coordiantes make sense.
For now just check that start is before end.

=cut
sub verify_target_coordinates {
    my $self = shift;

    DesignCreate::Exception->throw(
        'Target start: ' . $self->target_start .  ' is greater than target end: ' . $self->target_end
    ) if $self->target_start > $self->target_end;

    return;
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
