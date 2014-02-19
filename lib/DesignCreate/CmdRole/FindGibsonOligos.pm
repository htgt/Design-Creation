package DesignCreate::CmdRole::FindGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FindGibsonOligos::VERSION = '0.021';
}
## use critic


=head1 NAME

DesignCreate::Action::FindGibsonOligos - Use primer3 to find oligo pairs

=head1 DESCRIPTION

Using primer3 find oligo pairs for the three seperate regions in a
gibson design.

=cut

use Moose::Role;
use DesignCreate::Util::Primer3;
use DesignCreate::Exception;
use DesignCreate::Exception::Primer3FailedFindOligos;
use DesignCreate::Constants qw(
    $DEFAULT_OLIGO_COORD_FILE_NAME
    $PRIMER3_CONFIG_FILE
    %GIBSON_PRIMER_REGIONS
);
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt );
use YAML::Any qw( DumpFile LoadFile );
use Bio::Seq;
use Const::Fast;
use Data::Printer;
use namespace::autoclean;

const my @FIND_GIBSON_OLIGOS_PARAMETERS => qw(
primer_lowercase_masking
repeat_mask_class
primer_min_size
primer_max_size
primer_opt_size
primer_opt_gc_percent
primer_max_gc
primer_min_gc
primer_opt_tm
primer_max_tm
primer_min_tm
);

const my @PRIMER3_OPTIONS => qw(
    primer_lowercase_masking
    primer_min_size
    primer_max_size
    primer_opt_size
    primer_opt_gc_percent
    primer_max_gc
    primer_min_gc
    primer_opt_tm
    primer_max_tm
    primer_min_tm
);

has primer3_config_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    documentation => "File containing primer3 config details ( default $PRIMER3_CONFIG_FILE )",
    cmd_flag      => 'primer3-config-file',
    coerce        => 1,
    default       => sub{ Path::Class::File->new( $PRIMER3_CONFIG_FILE )->absolute },
);

has default_primer3_config => (
    is         => 'rw',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles => {
        has_primer3_default => 'exists',
        get_primer3_default => 'get',
    }
);

sub _build_default_primer3_config {
    my $self = shift;

    return LoadFile( $self->primer3_config_file->stringify );
}

# default of masking all sequence ensembl considers to be a repeat region
# means passing in undef as a mask method, otherwise pass in array ref of
# repeat classes
has repeat_mask_class => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt', 'Array' ],
    default       => sub{ [] },
    cmd_flag      => 'repeat-mask-class',
    documentation => "Optional repeat type class(s) we can get masked in genomic sequence",
    handles       => {
        no_repeat_mask_classes => 'is_empty'
    },
);

has oligo_region_coordinate_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    documentation => 'File containing oligo region coordinates ( default '
                     . "[design_dir]/oligo_target_regions/$DEFAULT_OLIGO_COORD_FILE_NAME  )",
    cmd_flag      => 'oligo-region-coord-file',
    coerce        => 1,
    lazy_build    => 1,
);

sub _build_oligo_region_coordinate_file {
    my $self = shift;

    return $self->get_file( $DEFAULT_OLIGO_COORD_FILE_NAME, $self->oligo_target_regions_dir );
}

has oligo_region_data => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt', 'Hash' ],
    lazy_build => 1,
    handles    => {
        get_region_coords  => 'get',
        have_region_coords => 'exists',
    }
);

sub _build_oligo_region_data {
    my $self = shift;

    return LoadFile( $self->oligo_region_coordinate_file );
}

has exon_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_slice {
    return shift->_build_region_slice( 'exon' );
}

has five_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_slice {
    return shift->_build_region_slice( 'five_prime' );
}

has three_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_slice {
    return shift->_build_region_slice( 'three_prime' );
}

has primer_lowercase_masking => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Should we send masked lowercase sequence into primer3, boolean',
    cmd_flag      => 'primer-lowercase-masking',
    predicate     => 'has_primer_lowercase_masking',
);

# setup primer3 config attributes
for my $name (
    qw(
    primer_min_size
    primer_max_size
    primer_opt_size
    primer_opt_gc_percent
    primer_max_gc
    primer_min_gc
    primer_opt_tm
    primer_max_tm
    primer_min_tm
    )
    )
{
    my $cmd_name;
    ( $cmd_name = $name ) =~ tr/\_/\-/;
    has $name => (
        is        => 'ro',
        isa       => PositiveInt,
        traits    => ['Getopt'],
        cmd_flag  => $cmd_name,
        predicate => 'has_' . $name,
        lazy      => 1,
        default   => sub {
            my $self = shift;
            die ("No Primer3 config for $name set") unless $self->has_primer3_default( $name );

            return $self->get_primer3_default( $name );
        }
    );
}

has primer3_results => (
    is         => 'ro',
    isa        => 'HashRef[Bio::Tools::Primer3Redux::Result]',
    traits     => [ 'NoGetopt' , 'Hash' ],
    default    => sub{ {  } },
    handles => {
        add_primer3_result => 'set',
        get_primer3_result => 'get',
    }
);

has primer3_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt', 'Hash' ],
    default => sub { {  } },
    handles => {
        has_oligos => 'count',
        get_oligos => 'get',
    }
);

has gibson_info => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_gibson_info {
    my $self = shift;
    my $design_method = $self->design_param( 'design_method' );
    return $GIBSON_PRIMER_REGIONS{$design_method};
}

has oligo_pairs => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => [ 'Hash', 'NoGetopt' ],
    default => sub{ {} },
    handles => {
        has_pairs => 'count',
        get_pairs => 'get',
    }
);

=head2 find_oligos

Find the oligos for the 3 target regions using primer3

=cut
sub find_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->set_param( 'ensembl-version', $self->ensembl_util->db_adaptor->dbc->dbname );
    $self->add_design_parameters( \@FIND_GIBSON_OLIGOS_PARAMETERS );
    # Add current EnsEMBL DB version used
    $self->run_primer3;
    $self->parse_primer3_results;
    $self->create_oligo_files;
    $self->update_design_attempt_record( { status => 'oligos_found' } );

    return;
}

=head2 run_primer3

Run primer3 against the 3 target regions.

=cut
sub run_primer3 {
    my ( $self ) = @_;

    my %primer3_params = (
        configfile => $self->primer3_config_file->stringify,
    );

    for my $name ( @PRIMER3_OPTIONS ) {
        $primer3_params{$name} = $self->$name;
    }

    my $p3 = DesignCreate::Util::Primer3->new_with_config( %primer3_params );

    my %failed_primer_regions;

    for my $region ( keys %{ $self->gibson_info } ) {
        $self->log->debug("Finding primers for $region primer region");
        my $log_file = $self->oligo_finder_output_dir->file( 'primer3_output_' . $region . '.log' );

        my $target_string  = $self->build_primer3_sequence_target_string($region);
        my $slice_name     = $self->gibson_info->{$region}{slice};
        my $region_slice   = $self->$slice_name;
        my $region_bio_seq = Bio::Seq->new( -display_id => $region, -seq => $region_slice->seq );

        my ( $result, $primer3_explain ) = $p3->run_primer3( $log_file->absolute, $region_bio_seq,
            { SEQUENCE_TARGET => $target_string }, $region );

        DesignCreate::Exception->throw( "Errors running primer3 on $region region" )
            unless $result;

        if ( $result->num_primer_pairs ) {
            $self->log->info( "$region primer region primer pairs: " . $result->num_primer_pairs );
            $self->add_primer3_result( $region => $result );
        }
        else {
            $self->log->warn( "Failed to generate primer pairs for $region region" );
            $failed_primer_regions{$region} = $primer3_explain;
        }
    }

    if (%failed_primer_regions) {
        DesignCreate::Exception::Primer3FailedFindOligos->throw(
            regions             => [ keys %failed_primer_regions ],
            primer_fail_reasons => \%failed_primer_regions,
        );
    }

    return;
}

=head2 parse_primer3_results

Extract the required information from the Bio::Tools::Primer3Redux::Result object
It outputs information about each primer pair.

=cut
sub parse_primer3_results {
    my ( $self ) = @_;

    for my $region ( keys %{ $self->gibson_info } ) {
        my $result = $self->get_primer3_result( $region );
        while ( my $pair = $result->next_primer_pair ) {
            my $forward_id = $self->parse_primer( $pair->forward_primer, $region, 'forward' );
            my $reverse_id = $self->parse_primer( $pair->reverse_primer, $region, 'reverse' );

            # store primer pair information seperately
            push @{ $self->oligo_pairs->{ $region } }, {
                $self->gibson_info->{$region}{forward} => $forward_id,
                $self->gibson_info->{$region}{reverse} => $reverse_id,
            };
        }
    }

    return;
}

=head2 parse_primer

Parse output required data from the Bio::Tools::Primer3Redux::Primer objects
( basically a Bio::SeqFeature::Generic object plus few other methods ).
Also add other calulated data about primer.

=cut
sub parse_primer {
    my ( $self, $primer, $region, $direction ) = @_;
    my %oligo_data;
    my $oligo_type  = $self->gibson_info->{$region}{$direction};
    my $primer_id   = $oligo_type . '-' . $primer->rank;
    $oligo_data{id} = $primer_id;

    DesignCreate::Exception->throw( "primer3 failed to validate sequence for primer: $primer_id" )
        unless $primer->validate_seq;

    $self->calculate_oligo_coords_and_sequence( $primer, $region, \%oligo_data, $direction );

    $oligo_data{oligo_length}    = $primer->length;
    $oligo_data{melting_temp}    = $primer->melting_temp;
    $oligo_data{gc_content}      = $primer->gc_content;
    $oligo_data{oligo_direction} = $direction;
    $oligo_data{rank}            = $primer->rank;
    $oligo_data{region}          = $region;
    $oligo_data{oligo}           = $oligo_type;

    push @{ $self->primer3_oligos->{ $oligo_type } }, \%oligo_data;

    return $oligo_data{id};
}

=head2 calculate_oligo_coords_and_sequence

Primer3 takes in sequence 5' to 3' so we need to work out the sequence in the
+ve strand plus its coordinates

=cut
sub calculate_oligo_coords_and_sequence{
    my ( $self, $primer, $region, $oligo_data, $direction ) = @_;

    my $region_coords = $self->get_region_coords( $region );
    $oligo_data->{target_region_start} = $region_coords->{start};
    $oligo_data->{target_region_end}   = $region_coords->{end};

    if ( $self->design_param('chr_strand') == 1 ) {
        $oligo_data->{oligo_start} = $region_coords->{start} + $primer->start - 1;
        $oligo_data->{oligo_end}   = $region_coords->{start} + $primer->end - 1;
        $oligo_data->{offset}      = $primer->start;
        $oligo_data->{oligo_seq}
            = $direction eq 'forward' ? $primer->seq->seq : $primer->seq->revcom->seq;
    }
    else {
        $oligo_data->{oligo_start} = $region_coords->{end} - $primer->end + 1;
        $oligo_data->{oligo_end}   = $region_coords->{end} - $primer->start + 1;
        $oligo_data->{offset}
            = ( $region_coords->{end} - $region_coords->{start} + 1 ) - $primer->end;
        $oligo_data->{oligo_seq}
            = $direction eq 'forward' ? $primer->seq->revcom->seq : $primer->seq->seq;
    }

    return;
}

=head2 create_oligo_files

Create a yaml file for a oligo type giving details
of the candidate oligos.

=cut
sub create_oligo_files {
    my $self = shift;
    $self->log->info('Creating oligo output files');

    DesignCreate::Exception->throw( 'No oligos found' )
        unless $self->has_oligos;

    for my $oligo ( keys %{ $self->primer3_oligos } ) {
        my $filename = $self->oligo_finder_output_dir->stringify . '/' . $oligo . '.yaml';
        DumpFile( $filename, $self->get_oligos( $oligo ) );
    }

    for my $region ( keys %{ $self->oligo_pairs } ) {
        my $filename = $self->oligo_finder_output_dir->stringify . '/' . $region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_pairs( $region ) );
    }

    return;
}

=head2 build_primer3_sequence_target_string

Build sequence target string that tells primer3 what region the primers must surround

=cut
sub build_primer3_sequence_target_string {
    my ( $self, $region ) = @_;

    DesignCreate::Exception->throw( "Details for $region region do not exist" )
        unless exists $self->gibson_info->{$region};
    my $forward_primer_size = $self->design_param( 'region_length_' . $self->gibson_info->{$region}{forward} );
    my $reverse_primer_size = $self->design_param( 'region_length_' . $self->gibson_info->{$region}{reverse} );
    my $slice_name = $self->gibson_info->{$region}{slice};

    my $target_length = $self->$slice_name->length - $forward_primer_size - $reverse_primer_size;
    return $forward_primer_size . ',' . $target_length;
}

=head2 _build_region_slice

Build a Bio::EnsEMBL::Slice for a given target regions

=cut
sub _build_region_slice {
    my ( $self, $region_name  ) = @_;

    my $coords = $self->get_region_coords( $region_name );
    DesignCreate::Exception->throw( "Unable to find coordinates for $region_name region" )
        unless $coords;

    my $slice = $self->get_repeat_masked_slice(
        $coords->{start}, $coords->{end}, $self->design_param( 'chr_name' ),
        $self->no_repeat_mask_classes ? undef : $self->repeat_mask_class
    );

    # primer3 expects sequence in a 5' to 3' direction, so reverse compliment if
    # target is on the -ve strand
    return $self->design_param( 'chr_strand' ) == 1 ? $slice : $slice->invert;
}

1;

__END__
