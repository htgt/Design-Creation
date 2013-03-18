package DesignCreate::CmdRole::ConsolidateDesignData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::ConsolidateDesignData::VERSION = '0.001';
}
## use critic


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
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use YAML::Any qw( LoadFile DumpFile );
use List::Util qw( first );
use namespace::autoclean;

with qw(
DesignCreate::Role::TargetSequence
DesignCreate::Role::Oligos
);

has target_genes => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt' ],
    documentation => 'Name of target gene(s) of design',
    required      => 1,
    cmd_flag      => 'target-gene',
);

has created_by => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Name of user, must be valid LIMS2 user ( default system )',
    default       => 'system',
    cmd_flag      => 'created-by',
);

has U_oligo_pair => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_U_oligo_pair {
    return shift->get_oligo_pair( 'U' );
}

has D_oligo_pair => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_D_oligo_pair {
    return shift->get_oligo_pair( 'D' );
}

has G_oligo_pair => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_G_oligo_pair {
    return shift->get_oligo_pair( 'G' );
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

    $self->log->info( 'Code to work out design phase not in place' );

    return;
}

sub build_oligo_array {
    my $self = shift;
    my @oligos;

    $self->log->info('Picking out design oligos');
    for my $oligo_type ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->get_file( "$oligo_type.yaml", $self->validated_oligo_dir );
        my $oligos = LoadFile( $oligo_file );

        push @oligos, $self->get_oligo( $oligos, $oligo_type );
    }

    $self->picked_oligos( \@oligos );

    return;
}

sub get_oligo {
    my ( $self, $oligos, $oligo_type ) = @_;
    my $oligo;

    if ( $oligo_type =~ /^G/ || $self->design_method eq 'conditional' ) {
        $oligo = $self->pick_oligo_from_pair( $oligos, $oligo_type );
    }
    else {
        $oligo = shift @{ $oligos };
    }

    DesignCreate::Exception->throw("Can not find $oligo_type oligo")
        unless $oligo;

    return $self->format_oligo_data( $oligo );
}

sub format_oligo_data {
    my ( $self, $oligo ) = @_;

    return {
        type => $oligo->{oligo},
        seq  => uc( $oligo->{oligo_seq} ),
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
        created_by => $self->created_by,
        oligos     => $self->picked_oligos,
    );

    $design_data{phase} = $self->phase if $self->phase;

    my $design_data_file = $self->dir->file( $self->design_data_file_name );
    $self->log->info( "Creating design file: $design_data_file" );
    DumpFile( $design_data_file, \%design_data );

    return;
}

sub get_oligo_pair {
    my ( $self, $type ) = @_;

    my $oligo_pair_file = $self->get_file( $type . '_oligo_pairs.yaml', $self->validated_oligo_dir );

    my $oligos = LoadFile( $oligo_pair_file );
    if ( !$oligos || !@{ $oligos } ) {
        DesignCreate::Exception->throw( "No oligo data in $oligo_pair_file" );
    }

    return shift @{ $oligos };
}

sub pick_oligo_from_pair {
    my ( $self, $oligos, $oligo_type ) = @_;

    my $oligo_region = substr( $oligo_type, 0,1 );
    my $pair_attribute = $oligo_region . '_oligo_pair';
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $pair_attribute,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($pair_attribute);

    my $oligo_id = $self->$pair_attribute->{$oligo_type};
    my $oligo = first{ $_->{id} eq $oligo_id } @{ $oligos };

    DesignCreate::Exception->throw( "Unable to find $oligo_type oligo: " . $oligo_id )
        unless $oligo;

    return $oligo;
}

1;

__END__
