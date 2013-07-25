package DesignCreate::CmdRole::FindGibsonOligos;

=head1 NAME

DesignCreate::Action::FindGibsonOligos -

=head1 DESCRIPTION


=cut

use Moose::Role;
use DesignCreate::Util::Primer3;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt YesNo Species Strand DesignMethod Chromosome );
use YAML::Any qw( DumpFile LoadFile );
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw( DesignCreate::Role::EnsEMBL );

const my @FIND_GIBSON_OLIGOS_PARAMETERS => qw(
mask_by_lower_case
repeat_mask_class
);

const my $DEFAULT_OLIGO_COORD_FILE_NAME => 'oligo_region_coords.yaml';

const my %PRIMER_DETAILS => (
    exon => {
        forward => 'ef',
        reverse => 'er',
        slice  => 'exon_region_slice'
    },
    five_prime => {
        forward => '5f',
        reverse => '5r',
        slice  => 'five_prime_region_slice'
    },
    three_prime => {
        forward => '3f',
        reverse => '3r',
        slice  => 'three_prime_region_slice'
    },
);

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
    handles => {
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

# primer3 expects sequence in a 5' to 3' direction
has exon_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_slice {
    my $self = shift;

    my $coords = $self->get_region_coords( 'exon' );
    my $start  = $coords->{start};
    my $end    = $coords->{end};

    my $slice = $self->get_repeat_masked_slice(
        $start, $end, $self->design_param( 'chr_name' ),
        $self->no_repeat_mask_classes ? undef : $self->repeat_mask_class
    );

    return $self->design_param( 'chr_strand' ) == 1 ? $slice : $slice->invert;
}

has five_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_slice {
    my $self = shift;

    my $coords = $self->get_region_coords( 'five_prime' );
    my $start  = $coords->{start};
    my $end    = $coords->{end};

    my $slice = $self->get_repeat_masked_slice(
        $start, $end, $self->design_param( 'chr_name' ),
        $self->no_repeat_mask_classes ? undef : $self->repeat_mask_class
    );

    return $self->design_param( 'chr_strand' ) == 1 ? $slice : $slice->invert;
}

has three_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_slice {
    my $self = shift;

    my $coords = $self->get_region_coords( 'three_prime' );
    my $start  = $coords->{start};
    my $end    = $coords->{end};

    my $slice = $self->get_repeat_masked_slice(
        $start, $end, $self->design_param( 'chr_name' ),
        $self->no_repeat_mask_classes ? undef : $self->repeat_mask_class
    );

    return $self->design_param( 'chr_strand' ) == 1 ? $slice : $slice->invert;
}

#TODO respect this flag sp12 Thu 18 Jul 2013 11:04:06 BST
has mask_by_lower_case => (
    is            => 'ro',
    isa           => YesNo,
    traits        => [ 'Getopt' ],
    documentation => 'Should we send masked lowercase sequence into primer3 ( default yes )',
    default       => 'yes',
    cmd_flag      => 'mask-by-lower-case',
);

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

blah

=cut
sub find_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@FIND_GIBSON_OLIGOS_PARAMETERS );

    $self->run_primer3;

    $self->parse_primer3_results;

    $self->create_oligo_files;

    return;
}

=head2 run_primer3

blah

=cut
sub run_primer3 {
    my ( $self ) = @_;

    #TODO make this a attribute sp12 Tue 23 Jul 2013 07:43:42 BST
    my $p3 = DesignCreate::Util::Primer3->new_with_config(
        configfile => '/nfs/users/nfs_s/sp12/workspace/Design-Creation/tmp/primer3/primer3_config.yaml',
    );

    for my $region ( keys %PRIMER_DETAILS ) {
        $self->log->debug("Finding primers for $region primer region");
        my $file = $self->oligo_finder_output_dir->file( 'primer3_output_' . $region . '.log' );

        my $target_string = $self->build_primer3_sequence_target_string( $region );

        my $slice_name = $PRIMER_DETAILS{$region}{slice};
        my $region_slice = $self->$slice_name;
        my $region_bio_seq = Bio::Seq->new( -display_id => $region, -seq => $region_slice->seq );

        my $result = $p3->run_primer3( $file->absolute, $region_bio_seq, { SEQUENCE_TARGET => $target_string } );

        if ( $result->warnings ) {
            $self->log->warn( "Primer3 warning: $_" ) for $result->warnings;
        };
        if ( $result->errors ) {
            $self->log->error( "Primer3 error: $_" ) for $result->errors;
        };

        if ( $result->num_primer_pairs ) {
            $self->log->info( "$region primer region primer pairs: " . $result->num_primer_pairs );
            $self->add_primer3_result( $region => $result );
        }
        else {
            die( "Can not find any primer pairs for $region primer region" );
        }
    }

    return;
}

=head2 parse_primer3_results

Extract the required information from the primer3 result objects

=cut
sub parse_primer3_results {
    my ( $self ) = @_;

    for my $region ( keys %PRIMER_DETAILS ) {

        my $result = $self->get_primer3_result( $region );
        while ( my $pair = $result->next_primer_pair ) {
            # are Bio::SeqFeature::Generic plus few other methods
            my $forward_id = $self->parse_primer( $pair->forward_primer, $region, 'forward' );
            my $reverse_id = $self->parse_primer( $pair->reverse_primer, $region, 'reverse' );

            push @{ $self->oligo_pairs->{ $region } }, {
                uc($PRIMER_DETAILS{$region}{forward}) => $forward_id,
                uc($PRIMER_DETAILS{$region}{reverse}) => $reverse_id,
            };
        }
    }

    return;
}

=head2 parse_primer

desc

=cut
sub parse_primer {
    my ( $self, $primer, $region, $direction ) = @_;
    my %oligo_data;

    unless ( $primer->validate_seq ) {
        die( 'failed to validate sequence' );
    }

    #TODO could replace this is variables worked out in last step?
    my $oligo_type = uc($PRIMER_DETAILS{$region}{$direction});
    my $region_slice_name = $PRIMER_DETAILS{$region}{slice};
    my $region_slice = $self->$region_slice_name;

    $oligo_data{target_region_start} = $region_slice->start;
    $oligo_data{target_region_end} = $region_slice->end;

    # Maybe able to use feature of Primer3Redux to help with all this
    # the forward seq is okay, the reverse primer sequence needs to be rev-comped
    # STRAND DEPENDANT
    if ( $self->design_param( 'chr_strand' ) == 1 ) {
        $oligo_data{oligo_start} = $region_slice->start + $primer->start - 1;
        $oligo_data{oligo_end} = $region_slice->start + $primer->end - 1;
        $oligo_data{offset} = $primer->start;
        $oligo_data{oligo_seq} = $direction eq 'forward' ? $primer->seq->seq : $primer->seq->revcom->seq;
    }
    else {
        $oligo_data{oligo_start} = $region_slice->end - $primer->end + 1;
        $oligo_data{oligo_end} = $region_slice->end - $primer->start + 1;
        $oligo_data{offset} = $region_slice->length - $primer->end;
        $oligo_data{oligo_seq} = $direction eq 'forward' ? $primer->seq->revcom->seq : $primer->seq->seq;
    }

    $oligo_data{oligo_length} = $primer->length;
    $oligo_data{melting_temp} = $primer->melting_temp;
    $oligo_data{gc_content} = $primer->gc_content;
    $oligo_data{oligo_direction} = $direction;
    $oligo_data{rank} = $primer->rank;
    $oligo_data{region} = $region;
    $oligo_data{oligo} = $oligo_type;
    $oligo_data{id} = $oligo_type . '-' . $primer->rank;

    push @{ $self->primer3_oligos->{ $oligo_type } }, \%oligo_data;

    return $oligo_data{id};
}

=head2 create_oligo_files


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

    my $forward_primer_size = $self->design_param( 'size_' . $PRIMER_DETAILS{$region}{forward} );
    my $reverse_primer_size = $self->design_param( 'size_' . $PRIMER_DETAILS{$region}{reverse} );
    my $slice_name = $PRIMER_DETAILS{$region}{slice};

    my $target_length = $self->$slice_name->length - $forward_primer_size - $reverse_primer_size;
    return $forward_primer_size . ',' . $target_length;
}

1;

__END__
