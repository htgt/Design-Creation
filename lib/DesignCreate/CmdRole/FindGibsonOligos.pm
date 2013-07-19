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

const my $DEFAULT_PRIMER3_WORK_DIR_NAME => 'primer3_work';

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
        region  => 'exon_region_seq'
    },
    five_prime => {
        forward => '5f',
        reverse => '5r',
        region  => 'five_prime_region_seq'
    },
    three_prime => {
        forward => '3f',
        reverse => '3r',
        region  => 'three_prime_region_seq'
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

has exon_region_seq => (
    is         => 'ro',
    isa        => 'Bio::Seq',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_seq {
    my $self = shift;

    my $start = $self->exon_start - ( $self->offset_ef + $self->size_ef );
    my $end = $self->exon_end + ( $self->offset_er + $self->size_er );

    return $self->_get_region_seq( $start, $end, 'exon_region' );
}

has five_prime_region_seq => (
    is         => 'ro',
    isa        => 'Bio::Seq',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_seq {
    my $self = shift;

    my $start = $self->exon_start - ( $self->offset_5f + $self->size_5f );
    my $end = $self->exon_start - $self->offset_5r;

    return $self->_get_region_seq( $start, $end, 'five_prime_region' );
}

has three_prime_region_seq => (
    is         => 'ro',
    isa        => 'Bio::Seq',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_seq {
    my $self = shift;

    my $start = $self->exon_end + $self->offset_3f;
    my $end = $self->exon_end + ( $self->offset_3r + $self->size_3r );

    return $self->_get_region_seq( $start, $end, 'three_prime_region' );
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

has primer3_work_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'NoGetopt' ],
    lazy_build    => 1,
);

sub _build_primer3_work_dir {
    my $self = shift;

    my $primer3_work_dir = $self->dir->subdir( $DEFAULT_PRIMER3_WORK_DIR_NAME )->absolute;
    $primer3_work_dir->rmtree();
    $primer3_work_dir->mkpath();

    return $primer3_work_dir;
}

=head2 find_oligos

blah

=cut
sub find_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@FIND_GIBSON_OLIGOS_PARAMETERS );

    $self->run_primer3;

    #$self->check_primer3_output; #??

    #$self->parse_primer3_output;

    #$self->create_oligo_files;
    # create the oligo pair files as well

    return;
}

=head2 run_primer3

blah

=cut
sub run_primer3 {
    my ( $self ) = @_;

    my $p3 = DesignCreate::Util::Primer3->new_with_config(
        configfile => '/nfs/users/nfs_s/sp12/workspace/Design-Creation/tmp/primer3/primer3_config.yaml',
    );

    for my $type ( keys %PRIMER_DETAILS ) {
        my $file = $self->primer3_work_dir->file( 'primer3_output_' . $type );

        my $region_name = $PRIMER_DETAILS{$type}{region};
        my $region_seq = $self->$region_name;

        my $target_string = $self->build_primer3_sequence_target_string( $type );

        my $result = $p3->run_primer3( $file->absolute, $region_seq, { SEQUENCE_TARGET => $target_string } );

        ### num primer pairs : $result->num_primer_pairs

        if ( $result->warnings ) {
            ### warnings : $result->warnings
        };
        if ( $result->errors ) {
            ### errors : $result->errors
        };

        while ( my $pair = $result->next_primer_pair ) {
            # are Bio::SeqFeature::Generic plus few other methods
            my $fp = $pair->forward_primer;
            my $rp = $pair->reverse_primer;
        }

    }
    
}

sub create_aos_query_file {
    my $self = shift;

    my $fh = $self->query_file->open( O_WRONLY|O_CREAT )
        or die( $self->query_file->stringify . " open failure: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo ( $self->expected_oligos ) {
        my $oligo_file = $self->get_file( "$oligo.fasta", $self->oligo_target_regions_dir );

        my $seq_in = Bio::SeqIO->new( -fh => $oligo_file->openr, -format => 'fasta' );
        $self->log->debug( "Adding $oligo oligo target sequence to query file" );

        while ( my $seq_obj = $seq_in->next_seq ) {
            $self->check_masked_seq( $seq_obj->seq, $oligo ) if $self->mask_by_lower_case eq 'yes';
            $seq_out->write_seq( $seq_obj );
        }
    }

    if ( $self->has_repeat_masked_oligo_regions ) {
        DesignCreate::Exception->throw(
            'Following oligo regions are completely repeat masked: '
            . $self->list_repeat_masked_oligo_regions( ',' )
        );
    }

    return;
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

# parse oligo data
#$oligo_data{target_region_start}
#$oligo_data{target_region_end}
#$oligo_data{oligo_start}
#$oligo_data{oligo_end}
#$oligo_data{oligo_length}
#$oligo_data{oligo_seq}
#$oligo_data{offset} ??
#$oligo_data{oligo}
#$oligo_data{id}

=head2 create_oligo_files


=cut
sub create_oligo_files {
    my $self = shift;
    $self->log->info('Creating oligo output files');

    DesignCreate::Exception->throw( 'No oligos found' )
        unless $self->has_oligos;

     #TODO also oligo pair files sp12 Thu 18 Jul 2013 11:07:52 BST

    for my $oligo ( keys %{ $self->aos_oligos } ) {
        my $filename = $self->aos_output_dir->stringify . '/' . $oligo . '.yaml';
        DumpFile( $filename, $self->get_oligos( $oligo ) );
    }

    return;
}

=head2 _get_region_seq

Get Bio::Seq object of primer region, repeat masked.

=cut
sub _get_region_seq {
    my ( $self, $start, $end, $type ) = @_;

    my $seq = $self->get_repeat_masked_sequence( $start, $end, $self->exon->seq_region_name, undef );

    my $bio_seq = Bio::Seq->new( -display_id => $type, -seq => $seq );

    return $bio_seq;
}

=head2 build_primer3_sequence_target_string

Build sequence target string that tells primer3 what region the primers must surround

=cut
sub build_primer3_sequence_target_string {
    my ( $self, $type ) = @_;
    my $forward_primer_size_attr = 'size_' . $PRIMER_DETAILS{$type}{forward};
    my $reverse_primer_size_attr = 'size_' . $PRIMER_DETAILS{$type}{reverse};
    my $region_name = $PRIMER_DETAILS{$type}{region};

    my $target_start = $self->$forward_primer_size_attr;
    my $target_length = $self->$region_name->length - $target_start - $self->$reverse_primer_size_attr; 
    return $target_start . ',' . $target_length; 
}

1;

__END__
