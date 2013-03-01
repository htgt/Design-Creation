package DesignCreate::Role::OligoTargetRegions;

=head1 NAME

DesignCreate::Role::OligoTargetRegions

=head1 DESCRIPTION

Common code for oligo target region finding commands.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants
use namespace::autoclean;

with qw(
DesignCreate::Role::TargetSequence
DesignCreate::Role::Oligos
);

#
# Gap oligo region parameters, common to all design types
#

has G5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G5 oligo candidate region',
    cmd_flag      => 'g5-region-length'
);

has G5_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G5 oligo candidate region',
    cmd_flag      => 'g5-region-offset'
);

has G3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G3 oligo candidate region',
    cmd_flag      => 'g3-region-length'
);

has G3_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G3 oligo candidate region',
    cmd_flag      => 'g3-region-offset'
);

sub _build_oligo_target_regions {
    my ( $self, $opts, $args ) = @_;

    for my $oligo ( @{ $self->expected_oligos } ) {
        $self->log->info( "Getting target region for $oligo oligo" );
        my ( $start, $end ) = $self->get_oligo_region_coordinates( $oligo );
        next if !defined $start || !defined $end;

        my $oligo_seq = $self->get_sequence( $start, $end );
        my $oligo_id = $self->create_oligo_id( $oligo, $start, $end );
        $self->write_sequence_file( $oligo, $oligo_id, $oligo_seq );
    }

    return;
}

sub create_oligo_id {
    my ( $self, $oligo, $start, $end ) = @_;

    return $oligo . ':' . $start . '-' . $end;
}

sub write_sequence_file {
    my ( $self, $oligo, $oligo_id, $seq ) = @_;

    my $bio_seq  = Bio::Seq->new( -seq => $seq, -id => $oligo_id );
    my $seq_file = $self->oligo_target_regions_dir->file( $oligo . '.fasta' );
    $self->log->debug( "Outputting sequence to file: $seq_file" );

    my $fh = $seq_file->open( O_WRONLY|O_CREAT ) or die( "Open $seq_file: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );
    $seq_out->write_seq( $bio_seq );

    return;
}

sub get_oligo_region_offset {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_offset';
    DesignCreate::Exception->throw( "Attribute $attribute_name does not exist" )
        unless  $self->meta->has_attribute( $attribute_name );

    return $self->$attribute_name;
}

sub get_oligo_region_length {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_length';
    DesignCreate::Exception->throw( "Attribute $attribute_name does not exist" )
        unless $self->meta->has_attribute( $attribute_name );

    return $self->$attribute_name;
}

1;

__END__
