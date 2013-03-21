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

has all_oligo_pairs => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        have_oligo_pairs => 'exists',
        get_oligo_class_pairs => 'get',
    }
);

sub _build_all_oligo_pairs {
    my $self = shift;
    my %oligo_pairs;
    my @oligo_class = $self->design_method eq 'conditional' ? qw( G U D ) : qw( G );

    for my $class ( @oligo_class ) {
        my $oligo_pair_file = $self->get_file( $class . '_oligo_pairs.yaml', $self->validated_oligo_dir );
        my $oligos = LoadFile( $oligo_pair_file );
        if ( !$oligos || !@{ $oligos } ) {
            DesignCreate::Exception->throw( "No oligo data in $oligo_pair_file" );
        }
        $oligo_pairs{$class} = $oligos;
    }

    return \%oligo_pairs;
}

has all_valid_oligos => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        get_oligos_of_type => 'get',
    }
);

sub _build_all_valid_oligos {
    my $self = shift;
    my %oligos;

    for my $oligo_type ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->get_file( "$oligo_type.yaml", $self->validated_oligo_dir );
        my $oligos = LoadFile( $oligo_file );
        if ( !$oligos || !@{ $oligos } ) {
            DesignCreate::Exception->throw( "No oligo data in $oligo_file" );
        }
        $oligos{$oligo_type} = $oligos;
    }

    return \%oligos;
}

has phase => (
    is     => 'rw',
    isa    => 'Int',
    traits => [ 'NoGetopt' ],
);

has primary_design_oligos => (
    is     => 'rw',
    isa    => 'ArrayRef',
    traits => [ 'NoGetopt' ],
);

has alternate_designs_oligos => (
    is     => 'rw',
    isa    => 'ArrayRef',
    traits => [ 'NoGetopt' ],
);

sub consolidate_design_data {
    my ( $self, $opts, $args ) = @_;

    $self->get_design_phase;

    $self->build_primary_design_oligos;
    $self->build_alternate_design_oligos;

    $self->create_primary_design_file;
    $self->create_alt_design_file if @{ $self->alternate_designs_oligos };

    return;
}

#TODO work out phase for design
sub get_design_phase {
    my $self = shift;

    $self->log->info( 'Code to work out design phase not in place' );

    return;
}

sub build_primary_design_oligos {
    my $self = shift;

    $self->log->info('Picking out primary design oligos');
    $self->primary_design_oligos( $self->build_design_oligo_data( 0 ) );
    return;
}

sub build_alternate_design_oligos {
    my $self = shift;
    my @alt_designs_data;
    my $design_num = 1;

    $self->log->info('Picking out alternative design oligos');
    while ( 1 ) {
        my $design_oligo_data = $self->build_design_oligo_data( $design_num );
        last unless $design_oligo_data;

        push @alt_designs_data, $design_oligo_data;
        $design_num++;
    }

    $self->alternate_designs_oligos( \@alt_designs_data );
    return;
}

sub build_design_oligo_data {
    my ( $self, $design_num ) = @_;
    my @design_oligo_data;

    for my $oligo_type ( @{ $self->expected_oligos } ) {
         my $design_oligo_data = $self->get_oligo( $oligo_type, $design_num );
         return unless $design_oligo_data;

         push @design_oligo_data, $design_oligo_data;
    }

    return \@design_oligo_data;
}

sub get_oligo {
    my ( $self, $oligo_type, $design_num ) = @_;
    my $oligo;

    if ( $oligo_type =~ /^G/ || $self->design_method eq 'conditional' ) {
        $oligo = $self->pick_oligo_from_pair( $oligo_type, $design_num );
    }
    else {
        my $oligos = $self->get_oligos_of_type( $oligo_type );
        $oligo = $oligos->[$design_num];
    }

    #throw error if this is the oligo for the primary design
    DesignCreate::Exception->throw("Can not find $oligo_type oligo")
        if !$oligo && $design_num == 0;
    return unless $oligo;

    return $self->format_oligo_data( $oligo );
}

sub pick_oligo_from_pair {
    my ( $self, $oligo_type, $design_num ) = @_;

    my $oligo_class = substr( $oligo_type, 0,1 );
    DesignCreate::Exception->throw( "Can not find information on $oligo_class oligo pairs")
        unless $self->have_oligo_pairs( $oligo_class );

    my $oligo_pairs = $self->get_oligo_class_pairs($oligo_class);
    my $oligo_id = $oligo_pairs->[$design_num]{$oligo_type};
    return unless $oligo_id;

    my $oligos = $self->get_oligos_of_type( $oligo_type );
    my $oligo = first{ $_->{id} eq $oligo_id } @{ $oligos };

    DesignCreate::Exception->throw( "Unable to find $oligo_type oligo: " . $oligo_id )
        unless $oligo;

    return $oligo;
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

sub create_primary_design_file {
    my $self = shift;
    my $design_data = $self->build_design_data( $self->primary_design_oligos );

    my $design_data_file = $self->dir->file( $self->design_data_file_name );
    $self->log->info( "Creating design file: $design_data_file" );
    DumpFile( $design_data_file, $design_data );

    return;
}

sub create_alt_design_file {
    my $self = shift;
    my @alt_design_data;

    for my $alt_design_oligos ( @{ $self->alternate_designs_oligos } ) {
        push @alt_design_data, $self->build_design_data( $alt_design_oligos );
    }

    my $alt_designs_file = $self->dir->file( $self->alt_design_data_file_name );
    $self->log->info( "Creating design file: $alt_designs_file" );
    DumpFile( $alt_designs_file, \@alt_design_data );

    return;
}

sub build_design_data {
    my ( $self, $oligos ) = @_;

    my %design_data = (
        type       => $self->design_method,
        species    => $self->species,
        gene_ids   => [ @{ $self->target_genes } ],
        created_by => $self->created_by,
        oligos     => $oligos,
    );

    $design_data{phase} = $self->phase if $self->phase;

    return \%design_data;
}

1;

__END__
