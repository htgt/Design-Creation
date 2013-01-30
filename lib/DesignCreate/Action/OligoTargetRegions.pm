package DesignCreate::Action::OligoTargetRegions;

=head1 NAME

DesignCreate::Action::OligoTargetRegions - Produce fasta files of the oligo target region sequences

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find.

=cut

#
# Initial version will be setup for standard deletion design only
#
#TODO
# setup config files to set some values below, don't use defaults

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants


extends qw( DesignCreate::Action );
#with 'MooseX::SimpleConfig';

has ensembl_util => (
    is         => 'ro',
    isa        => 'LIMS2::Util::EnsEMBL',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
    handles    => [ qw( slice_adaptor ) ],
);

sub _build_ensembl_util {
    my $self = shift;
    require LIMS2::Util::EnsEMBL;

    return LIMS2::Util::EnsEMBL->new( species => $self->species );
}

has seq_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_seq_dir {
    my $self = shift;

    my $seq_dir = $self->dir->subdir('oligo_target_regions');
    $seq_dir->mkpath();

    return $seq_dir;
}

has target_start => (
    is       => 'ro',
    isa      => 'Int',
    traits   => [ 'Getopt' ],
    required => 1,
    cmd_flag => 'target-start'
);

has target_end => (
    is       => 'ro',
    isa      => 'Int',
    traits   => [ 'Getopt' ],
    required => 1,
    cmd_flag => 'target-end'
);

has chr_name => (
    is       => 'ro',
    isa      => 'Str',
    traits   => [ 'Getopt' ],
    required => 1,
    cmd_flag => 'chromosome'
);

has chr_strand => (
    is       => 'ro',
    isa      => 'Int',
    traits   => [ 'Getopt' ],
    required => 1,
    cmd_flag => 'strand'
);

has species => (
    is       => 'ro',
    isa      => 'Str',
    traits   => [ 'Getopt' ],
    default  => 'mouse',
);

#TODO figure out how to get slice adapter for anything other than current assembly
has assembly => (
    is       => 'ro',
    isa      => 'Str',
    traits   => [ 'Getopt' ],
    default  => 'GRCm38'
);

#TODO this will be used to determine which oligos we need
#has design_method => (
    #is       => 'ro',
    #isa      => 'Str',
    #traits   => [ 'Getopt' ],
    #required => 1,
#);

#
# Oligo Target Region Parameters
# TODO Too many attributes here, confusing, need to clean this up
# maybe put all these attributes in a role? plus any relevent subroutines
#

has G5_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 1000,
);

has G5_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 4000,
);

has U5_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 200,
);

has U5_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 0,
);

has U3_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 200,
);

has U3_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 0,
);

has D5_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 200,
);

has D5_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 0,
);

has D3_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 200,
);

has D3_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 0,
);

has G3_region_length => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 1000,
);

has G3_region_offset => (
    is      => 'ro',
    isa     => 'Int',
    traits  => [ 'Getopt' ],
    default => 4000,
);

sub BUILD {
    my $self = shift;

    if ( $self->target_start > $self->target_end ) {
        $self->log->logdie( 'Target start ' . $self->target_start .  ' is greater than target end ' . $self->target_end );
    }

}

sub execute {
    my ( $self, $opts, $args ) = @_;

    my @oligos = qw( G5 U5 D3 G3 );

    for my $oligo ( @oligos ) {
        my ( $start, $end ) = $self->get_oligo_region_coordinates( $oligo );
        next if !defined $start || !defined $end;

        my $oligo_seq = $self->get_sequence( $start, $end );
        my $oligo_id = $self->create_oligo_id( $oligo, $start, $end );
        $self->write_sequence_file( $oligo, $oligo_id, $oligo_seq );
    }
}

sub get_oligo_region_coordinates {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    # Only works for deletion/ insertion designs
    if ( $oligo =~ /5$/ ) {
        $start = $self->target_start - ( $offset + $length );
        $end   = $self->target_start - ( $offset + 1 );
    }
    elsif ( $oligo =~ /3$/ ) {
        $start = $self->target_end + ( $offset + 1 );
        $end   = $self->target_end + ( $offset + $length );
    }
    else {
        $self->log->error( "Invalid oligo name $oligo" );
    }

    if ( $start > $end ) {
        $self->log->error( "Start $start, greater than end $end for oligo $oligo" );
        return;
    }

    return( $start, $end );
}

sub get_oligo_region_offset {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_offset';
    unless ( $self->meta->has_attribute( $attribute_name ) ) {
        $self->log->error( "Attribute $attribute_name does not exist" );
        return;
    }

    return $self->$attribute_name;
}

sub get_oligo_region_length {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_length';
    unless ( $self->meta->has_attribute( $attribute_name ) ) {
        $self->log->error( "Attribute $attribute_name does not exist" );
        return;
    }

    return $self->$attribute_name;
}

sub create_oligo_id {
    my ( $self, $oligo, $start, $end ) = @_;

    return $oligo . ':' . $start . '-' . $end;
}

sub write_sequence_file {
    my ( $self, $oligo, $oligo_id, $seq ) = @_;

    my $bio_seq  = Bio::Seq->new( -seq => $seq, -id => $oligo_id );
    my $seq_file = $self->seq_dir->file( $oligo . '.fasta' );

    # write-only,create file if it does not exist,fail if fail already exists
    my $fh = $seq_file->open( O_WRONLY|O_CREAT|O_EXCL ) or die( "Open $seq_file: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );
    $seq_out->write_seq( $bio_seq );
}

#TODO: check valid sequence found
sub get_sequence {
    my ( $self, $start, $end ) = @_;

    my $slice = $self->slice_adaptor->fetch_by_region(
        'chromosome',
        $self->chr_name,
        $start,
        $end,
        $self->chr_strand,
    );

    return $slice->seq;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
