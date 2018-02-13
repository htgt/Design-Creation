package DesignCreate::CmdRole::ConsolidateShortenArmDesignData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::ConsolidateShortenArmDesignData::VERSION = '0.046';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::ConsolidateShortenArmDesignData - Bring together all the design data into one file

=head1 DESCRIPTION

NOTE: This is a modified version of the DesignCreate::CmdRole::ConsolidateDesignData role.
Create one yaml file containing all the data for one short arm design.
This means getting the U / D oligos from the original design and merging
them with the new G oligos that produce shorter arms.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use YAML::Any qw( LoadFile DumpFile );
use JSON;
use List::Util qw( first );
use DateTime;
use Const::Fast;
use namespace::autoclean;

const my @DESIGN_PARAMETERS => qw(
created_by
software_version
);

has original_design => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_original_design {
    my $self = shift;

    my $original_design_data_file = $self->get_file( 'original_lims2_design.yaml', $self->dir );
    my $original_design_data = LoadFile( $original_design_data_file );

    return $original_design_data;
}

has created_by => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Name of user, must be valid LIMS2 user ( default system )',
    default       => 'system',
    cmd_flag      => 'created-by',
);

has software_version => (
    is         => 'ro',
    isa        => 'Str',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

has design_comment => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Optional design comment',
    cmd_flag      => 'design-comment',
);

sub _build_software_version {
    my $self = shift;

    my $t = DateTime->today();
    return $DesignCreate::Role::Action::VERSION || 'dev_' . $t->dmy;
}

# NOTE: In this case its only the G oligo pairs we look at
has all_oligo_pairs => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        have_oligo_pairs      => 'exists',
        get_oligo_class_pairs => 'get',
    }
);

sub _build_all_oligo_pairs {
    my $self = shift;
    my %oligo_pairs;

    my $oligo_pair_file = $self->get_file( 'G_oligo_pairs.yaml', $self->validated_oligo_dir );
    my $oligos = LoadFile( $oligo_pair_file );
    if ( !$oligos || !@{ $oligos } ) {
        DesignCreate::Exception->throw( "No oligo data in $oligo_pair_file" );
    }
    $oligo_pairs{G} = $oligos;

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

    for my $oligo_type ( $self->expected_oligos ) {
        my $oligo_file = $self->get_file( "$oligo_type.yaml", $self->validated_oligo_dir );
        my $oligos = LoadFile( $oligo_file );
        if ( !$oligos || !@{ $oligos } ) {
            DesignCreate::Exception->throw( "No oligo data in $oligo_file" );
        }
        $oligos{$oligo_type} = $oligos;
    }

    return \%oligos;
}

has design_genes => (
    is         => 'ro',
    isa        => 'ArrayRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_design_genes {
    my $self = shift;
    my @design_genes;

    my @gene_ids = @{ $self->design_param( 'target_genes' ) };

    for my $gene_id ( @gene_ids ) {
        my $gene_type = $self->calculate_gene_type( $gene_id );
        push @design_genes, { gene_id => $gene_id, gene_type_id => $gene_type };
    }

    return \@design_genes;
}

has primary_design_oligos => (
    is     => 'rw',
    isa    => 'ArrayRef',
    traits => [ 'NoGetopt' ],
);

sub consolidate_design_data {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    $self->build_primary_design_oligos;
    $self->create_primary_design_file;

    $self->update_design_attempt_record( { status => 'design_data_consolidated' } );

    return;
}

sub build_primary_design_oligos {
    my $self = shift;

    $self->log->info('Picking out primary design oligos');
    $self->primary_design_oligos( $self->build_design_oligo_data( 0 ) );
    return;
}

sub build_design_oligo_data {
    my ( $self, $design_num ) = @_;
    my @design_oligo_data;

    for my $oligo_type ( $self->expected_oligos ) {
         my $design_oligo_data = $self->get_oligo( $oligo_type, $design_num );
         return unless $design_oligo_data;

         push @design_oligo_data, $design_oligo_data;
    }

    $self->merge_original_design_oligos( \@design_oligo_data );

    return \@design_oligo_data;
}

sub get_oligo {
    my ( $self, $oligo_type, $design_num ) = @_;

    my $oligo = $self->pick_oligo_from_pair( $oligo_type, $design_num );

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
                assembly   => $self->design_param( 'assembly' ),
                chr_start  => $oligo->{oligo_start},
                chr_end    => $oligo->{oligo_end},
                chr_name   => $self->design_param( 'chr_name' ),
                chr_strand => $self->design_param( 'chr_strand' ),
            }
        ]
    };
}

=head2 merge_original_design_oligos

Merge U and D oligos from original design with new G oligos

=cut
sub merge_original_design_oligos {
    my ( $self, $oligos ) = @_;

    my @original_oligos = grep { $_->{type} !~ /^G/ } @{ $self->original_design->{oligos} };

    for my $oligo_data ( @original_oligos ) {
        delete $oligo_data->{id};
        my $locus = delete $oligo_data->{locus};
        $oligo_data->{loci} = [
            {
                assembly   => $locus->{assembly},
                chr_start  => $locus->{chr_start},
                chr_end    => $locus->{chr_end},
                chr_name   => $locus->{chr_name},
                chr_strand => $locus->{chr_strand},
            }
        ];
        push @{ $oligos }, $oligo_data;
    }

    return;
}

sub create_primary_design_file {
    my $self = shift;
    my $design_data = $self->build_design_data( $self->primary_design_oligos );

    my $design_data_file = $self->dir->file( $self->design_data_file_name );
    $self->log->info( "Creating design file: $design_data_file" );
    DumpFile( $design_data_file, $design_data );

    return;
}

sub build_design_data {
    my ( $self, $oligos ) = @_;

    my %design_data = (
        type                 => $self->original_design->{type},
        species              => $self->original_design->{species},
        gene_ids             => $self->design_genes,
        created_by           => $self->created_by,
        oligos               => $oligos,
        design_parameters    => encode_json( $self->design_parameters ),
        global_arm_shortened => $self->original_design->{id},
    );

    # Optional information
    for my $type ( qw( phase target_transcript cassette_first ) ) {
        $design_data{$type } = $self->original_design->{$type}
            if exists $self->original_design->{$type};
    }

    if ( $self->design_comment ) {
        $design_data{comments} = [
            {
                category     => 'Other',
                comment_text => $self->design_comment,
                created_by   => $self->created_by,
            }
        ];
    }

    return \%design_data;
}

=head2 calculate_gene_type

Work out type of gene identifier.

=cut
sub calculate_gene_type {
    my ( $self, $gene_id ) = @_;

    my $gene_type = $gene_id =~ /^MGI/  ? 'MGI'
                  : $gene_id =~ /^HGNC/ ? 'HGNC'
                  : $gene_id =~ /^LBL/  ? 'enhancer-region'
                  : $gene_id =~ /^CGI/  ? 'CPG-island'
                  : $gene_id =~ /^mmu/  ? 'miRBase'
                  :                       'marker-symbol'
                  ;

    return $gene_type;
}

1;

__END__
