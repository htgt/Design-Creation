package DesignCreate::CmdRole::FindOligos;

=head1 NAME

DesignCreate::Action::FindOligos - Get oligos for a design

=head1 DESCRIPTION

Finds a selection of oligos for a design given the oligos target ( candidate ) regions.
This is a wrapper around RunAOS which does the real work.

=cut

use Moose::Role;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::AOS
DesignCreate::Role::TargetSequence
DesignCreate::Role::Oligos
);

requires qw(
oligo_target_regions_dir
aos_output_dir
);

# Don't need the following attributes when running this command on its own
__PACKAGE__->meta->remove_attribute( 'chr_strand' );
__PACKAGE__->meta->remove_attribute( 'species' );

const my $DEFAULT_CHROMOSOME_DIR => $ENV{AOS_CHROMOSOME_DIR}
    || '/lustre/scratch101/blastdb/Users/vvi/KO_MOUSE/GRCm38';

has query_file => (
    is         => 'ro',
    isa        => AbsFile,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_query_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( 'all_target_regions.fasta' );

    return $file;
}

has target_file => (
    is            => 'rw',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    documentation => "Target file for AOS ( defaults to chromosome sequence of design )",
    cmd_flag      => 'target-file',
    predicate     => 'has_user_defined_target_file',
);

has base_chromosome_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    default       => sub{ Path::Class::Dir->new( $DEFAULT_CHROMOSOME_DIR )->absolute },
    documentation => "Location of chromosome files ( default $DEFAULT_CHROMOSOME_DIR )",
    cmd_flag      => 'base-chromosome-dir'
);

sub find_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->create_aos_query_file;
    $self->define_target_file;
    $self->run_aos;
    $self->check_aos_output;

    return;
}

# put all oligo target regions in one query file and run that
sub create_aos_query_file {
    my $self = shift;

    my $fh = $self->query_file->open( O_WRONLY|O_CREAT )
        or die( $self->query_file->stringify . " open failure: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->oligo_target_regions_dir->file( $oligo . '.fasta' );
        unless ( $self->oligo_target_regions_dir->contains( $oligo_file ) ) {
            $self->log->logdie("Can't find $oligo target region file: $oligo_file");
        }

        my $seq_in = Bio::SeqIO->new( -fh => $oligo_file->openr, -format => 'fasta' );
        $self->log->debug( "Adding $oligo oligo target sequence to query file" );

        while ( my $seq = $seq_in->next_seq ) {
            $seq_out->write_seq( $seq );
        }
    }
    $self->log->debug('AOS query file created: ' . $self->query_file->stringify );

    return;
}

sub define_target_file {
    my $self = shift;

    if ( $self->has_user_defined_target_file ) {
        $self->log->debug( 'We have a user defined target file: ' . $self->target_file->stringify );
        return;
    }

    my $chr_file = $self->base_chromosome_dir->file( $self->chr_name . '.fasta' );
    if ( $self->base_chromosome_dir->contains( $chr_file ) ) {
        $self->log->debug( "Target file found: $chr_file" );
        $self->target_file( $chr_file );
    }
    else {
        $self->log->logdie( "Unable to find target file $chr_file in dir: "
                           . $self->base_chromosome_dir->stringify )
    }

    return;
}

sub check_aos_output {
    my $self = shift;

    for my $oligo ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->aos_output_dir->file( $oligo . '.yaml' );
        unless ( $self->aos_output_dir->contains( $oligo_file ) ) {
            $self->log->logdie("Can't find $oligo oligo file: $oligo_file");
        }
    }

    $self->log->info('All oligo yaml files are present');
    return;
}


1;

__END__
