package DesignCreate::CmdRole::FindGibsonOligos;

=head1 NAME

DesignCreate::Action::FindGibsonOligos -

=head1 DESCRIPTION


=cut

use Moose::Role;
use DesignCreate::Util::Primer3;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt YesNo Species );
use YAML::Any qw( DumpFile );
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

use Smart::Comments;

with qw(
DesignCreate::Role::EnsEMBL
);

const my @FIND_GIBSON_OLIGOS_PARAMETERS => qw(
species
target_exon
mask_by_lower_case
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

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target ( Human or Mouse )',
    required      => 1,
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

has exon_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
 );

sub _build_exon_start {
    shift->exon->seq_region_start;
}

has exon_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_end {
    shift->exon->seq_region_end;
}

has exon_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_slice {
    my $self = shift;

    my $start = $self->exon_start - ( $self->offset_ef + $self->size_ef );
    my $end = $self->exon_end + ( $self->offset_er + $self->size_er );

    return $self->get_repeat_masked_slice( $start, $end, $self->exon->seq_region_name, undef );
}

has five_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_slice {
    my $self = shift;

    my $start = $self->exon_start - ( $self->offset_5f + $self->size_5f );
    my $end = $self->exon_start - $self->offset_5r;

    return $self->get_repeat_masked_slice( $start, $end, $self->exon->seq_region_name, undef );
}

has three_prime_region_slice => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Slice',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_slice {
    my $self = shift;

    my $start = $self->exon_end + $self->offset_3f;
    my $end = $self->exon_end + ( $self->offset_3r + $self->size_3r );

    return $self->get_repeat_masked_slice( $start, $end, $self->exon->seq_region_name, undef );
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

    my $oligo_type = uc($PRIMER_DETAILS{$region}{$direction});
    my $region_slice_name = $PRIMER_DETAILS{$region}{slice};
    my $region_slice = $self->$region_slice_name;

    $oligo_data{target_region_start} = $region_slice->start + $primer->start;
    $oligo_data{target_region_end} = $region_slice->start + $primer->end;
    $oligo_data{oligo_start} = $primer->start;
    $oligo_data{oligo_end} = $primer->end;
    $oligo_data{oligo_length} = $primer->length;
    $oligo_data{oligo_seq} = $primer->seq->seq;
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

=head2 check_masked_seq

check if entire region is repeat masked

=cut
sub check_masked_seq {
    my ( $self, $seq, $oligo ) = @_;

    if ( $seq =~ /^[actg]+$/ ) {
        $self->add_repeat_masked_oligo_region( $oligo );
    }

    return;
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
    my $forward_primer_size_attr = 'size_' . $PRIMER_DETAILS{$region}{forward};
    my $reverse_primer_size_attr = 'size_' . $PRIMER_DETAILS{$region}{reverse};
    my $slice_name = $PRIMER_DETAILS{$region}{slice};

    my $target_start = $self->$forward_primer_size_attr;
    my $target_length = $self->$slice_name->length - $target_start - $self->$reverse_primer_size_attr;
    return $target_start . ',' . $target_length;
}

1;

__END__
