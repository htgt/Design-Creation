package DesignCreate::CmdRole::TargetLocation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::TargetLocation::VERSION = '0.026';
}
## use critic


=head1 NAME

DesignCreate::Action::TargetLocation - target region coordinates for user specified location

=head1 DESCRIPTION

For given genome location calculate target region coordinates for design.

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
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Genomic start coordinate of target',
    required      => 1,
    cmd_flag      => 'target-start'
);

has target_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Genomic end coordinate of target',
    required      => 1,
    cmd_flag      => 'target-end'
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
