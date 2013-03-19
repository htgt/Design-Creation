package DesignCreate::CmdRole::FetchOligoRegionsSequence;

=head1 NAME

DesignCreate::CmdRole::FetchOligoRegionsSequence - Create seq files for oligo region

=head1 DESCRIPTION

Given a file specifying the coordinates of oligo regions produce fasta sequence files
for each of the oligo regions.

=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Bio::SeqIO;
use Bio::Seq;
use Const::Fast;
use Fcntl; # O_ constants
use YAML::Any qw( LoadFile );
use namespace::autoclean;

with qw(
DesignCreate::Role::EnsEMBL
DesignCreate::Role::Oligos
);

const my $DEFAULT_OLIGO_COORD_FILE_NAME => 'oligo_region_coords.yaml';

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
        get_oligo_region_coords  => 'get',
        have_oligo_region_coords => 'exists',
    }
);

sub _build_oligo_region_data {
    my $self = shift;

    return LoadFile( $self->oligo_region_coordinate_file );
}

sub create_oligo_region_sequence_files {
    my $self = shift;

    for my $oligo ( @{ $self->expected_oligos } ) {
        $self->log->info( "Getting sequence for $oligo oligo region" );

        DesignCreate::Exception->throw(
            "No oligo region coordinate information found for $oligo oligo region"
        ) unless $self->have_oligo_region_coords( $oligo );

        my $coords   = $self->get_oligo_region_coords( $oligo );
        my $start    = $coords->{start};
        my $end      = $coords->{end};
        #TODO grab chromosome for params file
        my $chr_name = $coords->{chromosome};

        my $oligo_seq = $self->get_repeat_masked_sequence( $start, $end, $chr_name );
        my $oligo_id  = $self->create_oligo_id( $oligo, $start, $end );
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