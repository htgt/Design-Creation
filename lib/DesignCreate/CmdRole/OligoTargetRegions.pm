package DesignCreate::CmdRole::OligoTargetRegions;

=head1 NAME

DesignCreate::CmdRole::OligoTargetRegions - Produce fasta files of the oligo target region sequences

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find. ( Also called candidate region )

=cut

#
# Initial version will be setup for standard deletion design only
#

#TODO setup config files to set some values below, don't use defaults

use Moose::Role;
use Bio::SeqIO;
use Bio::Seq;
use DesignCreate::Exception;
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
