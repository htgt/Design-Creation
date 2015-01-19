package DesignCreate::CmdRole::FilterOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FilterOligos::VERSION = '0.033';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::FilterOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt );
use DesignCreate::Util::Exonerate;
use DesignCreate::Exception;
use DesignCreate::Constants qw( $DEFAULT_EXONERATE_OLIGO_DIR_NAME );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use Bio::SeqIO;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::FilterOligos
);

const my @DESIGN_PARAMETERS => qw(
flank_length
);

has exonerate_query_file => (
    is     => 'rw',
    isa    => AbsFile,
    traits => [ 'NoGetopt' ],
);

has exonerate_target_file => (
    is            => 'rw',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    documentation => "Target file for exonerate ( defaults to 100000 bases flanking design target )",
    cmd_flag      => 'exonerate-target-file',
    predicate     => 'has_exonerate_target_file',
);

has flank_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Number of bases to either side of G5 and G3 where we check for oligo specificity'
                     . ' ( default 100000 )',
    cmd_flag      => 'flank-length',
    default       => 100000
);

has exonerate_oligo_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exonerate_oligo_dir {
    my $self = shift;

    my $exonerate_oligo_dir = $self->dir->subdir( $DEFAULT_EXONERATE_OLIGO_DIR_NAME )->absolute;
    $exonerate_oligo_dir->rmtree();
    $exonerate_oligo_dir->mkpath();

    return $exonerate_oligo_dir;
}

has exonerate_matches => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

sub filter_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->run_exonerate;
    # the following commands are consumed from DesignCreate::Role::FilterOligos
    $self->validate_oligos;
    $self->output_validated_oligos;

    return;
}

=head2 _validate_oligo

Run checks against individual oligo to make sure it is valid.
If it passes all checks return 1, otherwise return undef.

=cut
## no critic(Subroutines::ProhibitUnusedPrivateSubroutine)
sub _validate_oligo {
    my ( $self, $oligo_data, $oligo_type, $oligo_slice ) = @_;

    $self->check_oligo_coordinates( $oligo_data ) or return;
    $self->check_oligo_sequence( $oligo_data, $oligo_slice ) or return;
    $self->check_oligo_length( $oligo_data ) or return;
    $self->check_oligo_specificity(
        $oligo_data->{id},
        $self->exonerate_matches->{ $oligo_data->{id} }
    ) or return;

    return 1;
}
## use critic

sub check_oligo_coordinates {
    my ( $self, $oligo_data ) = @_;

    if ( $oligo_data->{oligo_start} != ( $oligo_data->{target_region_start} + $oligo_data->{offset} ) ) {
        $self->log->error('Oligo start coordinates incorrect: ' . $oligo_data->{id} );
        return 0;
    }

    if ( $oligo_data->{oligo_end} != ( $oligo_data->{oligo_start} + ( $oligo_data->{oligo_length} - 1 ) ) ) {
        $self->log->error('Oligo end coordinates incorrect: ' . $oligo_data->{id} );
        return 0;
    }

    $self->log->debug('Coordinates look correct');
    return 1;
}

=head2 check_oligo_specificity

Send in exonerate match information for a given oligo.
Return 1 if it passes checks, undef otherwise.

=cut
sub check_oligo_specificity {
    my ( $self, $oligo_id, $match_info ) = @_;
    # if we have no match info then fail oligo
    return unless $match_info;

    if ( !$match_info->{exact_matches} ) {
        $self->log->error( 'Oligo ' . $oligo_id
            . ' does not have any exact matches, somethings wrong' );
        return;
    }
    elsif ( $match_info->{exact_matches} > 1 ) {
        $self->log->info( 'Oligo ' . $oligo_id
            . ' is invalid, has multiple exact matches: ' . $match_info->{exact_matches} );
        return;
    }
    # a hit is above 80% similarity
    elsif ( $match_info->{hits} > 1 ) {
        $self->log->info( 'Oligo ' . $oligo_id
            . ' is invalid, has multiple hits: ' . $match_info->{hits} );
        return;
    }

    return 1;
}

=head2 run_exonerate

Run exonerate against all our oligo candidates.
Build up a hash of exonerate hits keyed against the oligo ids.

=cut
sub run_exonerate {
    my $self = shift;
    $self->define_exonerate_query_file;
    $self->define_exonerate_target_file;

    # now run exonerate
    my $exonerate = DesignCreate::Util::Exonerate->new(
        target_file => $self->exonerate_target_file->stringify,
        query_file  => $self->exonerate_query_file->stringify,
    );

    $exonerate->run_exonerate;
    # put exonerate output in a log file
    my $exonerate_output = $self->exonerate_oligo_dir->file('exonerate_output.log');
    my $fh = $exonerate_output->open( O_WRONLY|O_CREAT ) or die( "Open $exonerate_output: $!" );
    print $fh $exonerate->raw_output;

    my $matches = $exonerate->parse_exonerate_output;
    DesignCreate::Exception->throw("No output from exonerate")
        unless $matches;

    $self->exonerate_matches( $matches );

    return;
}

sub define_exonerate_query_file {
    my $self = shift;

    my $query_file = $self->exonerate_oligo_dir->file('exonerate_query.fasta');
    my $fh         = $query_file->open( O_WRONLY|O_CREAT ) or die( "Open $query_file: $!" );
    my $seq_out    = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo_type ( keys %{ $self->all_oligos } ) {
        for my $oligo ( values %{ $self->all_oligos->{$oligo_type} } ) {
            my $bio_seq  = Bio::Seq->new( -seq => $oligo->{oligo_seq}, -id => $oligo->{id} );
            $seq_out->write_seq( $bio_seq );
        }
    }

    $self->log->debug("Created exonerate query file $query_file");
    $self->exonerate_query_file( $query_file );
    return;
}

sub define_exonerate_target_file {
    my $self = shift;

    if ( $self->has_exonerate_target_file ) {
        $self->log->debug( 'We have a user defined exonerate target file: '
            . $self->exonerate_target_file->stringify );
        return;
    }

    my $target_file = $self->exonerate_oligo_dir->file('exonerate_target.fasta');
    my $fh          = $target_file->open( O_WRONLY|O_CREAT ) or die( "Open $target_file: $!" );
    my $seq_out     = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    my $target_seq;
    try{
       $target_seq = $self->get_sequence( $self->target_flanking_region_coordinates );
    } catch {
        DesignCreate::Exception->throw( "We could not get exonerate target file sequence . $_" );
    };

    my $bio_seq  = Bio::Seq->new( -seq => $target_seq, -id => 'exonerate_target_sequence' );
    $seq_out->write_seq( $bio_seq );

    $self->log->debug("Created exonerate target file $target_file");
    $self->exonerate_target_file( $target_file );
    return;
}

sub target_flanking_region_coordinates {
    my $self = shift;
    my ( $start, $end );

    my $strand = $self->design_param( 'chr_strand' );
    my $g5_oligo = ( values %{ $self->all_oligos->{G5} } )[0];
    my $g3_oligo = ( values %{ $self->all_oligos->{G3} } )[0];
    if ( $strand == 1 ) {
        $start = $g5_oligo->{target_region_start};
        $end   = $g3_oligo->{target_region_end};
    }
    else {
        $start = $g3_oligo->{target_region_start};
        $end   = $g5_oligo->{target_region_end};
    }

    my $flanking_region_start = $start - $self->flank_length;
    my $flanking_region_end = $end + $self->flank_length;

    return( $flanking_region_start, $flanking_region_end, $self->design_param( 'chr_name' ) );
}

1;

__END__
