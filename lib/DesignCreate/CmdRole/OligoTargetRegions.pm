package DesignCreate::CmdRole::OligoTargetRegions;

=head1 NAME

DesignCreate::CmdRole::OligoTargetRegions - Produce fasta files of the oligo target region sequences

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find.

=cut

#
# Initial version will be setup for standard deletion design only
#

#TODO setup config files to set some values below, don't use defaults
#TODO work with conditional designs too

use Moose::Role;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants

with qw(
DesignCreate::Role::TargetSequence
DesignCreate::Role::Oligos
DesignCreate::Role::OligoRegionParameters
);

sub build_oligo_target_regions {
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
    my $seq_file = $self->oligo_target_regions_dir->file( $oligo . '.fasta' );
    $self->log->debug( "Outputting sequence to file: $seq_file" );

    my $fh = $seq_file->open( O_WRONLY|O_CREAT ) or die( "Open $seq_file: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );
    $seq_out->write_seq( $bio_seq );

    return;
}

1;

__END__
