package DesignCreate::CmdRole::FilterGibsonOligos;

=head1 NAME

DesignCreate::CmdRole::FilterGibsonOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use Moose::Role;
use DesignCreate::Exception;
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( NaturalNumber );
use DesignCreate::Util::Exonerate;
use DesignCreate::Constants qw( $DEFAULT_EXONERATE_OLIGO_DIR_NAME );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use List::MoreUtils qw( any );
use namespace::autoclean;
use Bio::SeqIO;

with qw(
DesignCreate::Role::FilterOligos
);

const my @DESIGN_PARAMETERS => qw(
exon_check_flank_length
);

const my %GENOME_FILES => (
    Mouse => '/lustre/scratch110/blastdb/Ensembl/Mouse/GRCm38/unmasked/toplevel.fa',
    Human => '/lustre/scratch110/blastdb/Ensembl/Human/GRCh37/genome/unmasked/toplevel.primary.single_chrY_without_Ns.unmasked.fa',
);

has exon_check_flank_length => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Number of flanking bases surrounding middle oligos to check for exons,'
                     . ' set to 0 to turn off check',
    cmd_flag      => 'exon-check-flank-length',
    default       => 100,
);

has validated_oligo_pairs => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'Hash', 'NoGetopt' ],
    default => sub{ {} },
    handles => {
        get_valid_pairs        => 'get',
        region_has_oligo_pairs => 'exists',
    }
);

sub filter_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->run_exonerate;

    # the following 2 commands are consumed from DesignCreate::Role::FilterOligos
    $self->validate_oligos;
    $self->output_validated_oligos;

    $self->validate_oligo_pairs;
    $self->output_valid_oligo_pairs;

    return;
}

=head2 _validate_oligo

Run checks against individual oligo to make sure it is valid.
If it passes all checks return 1, otherwise return undef.

=cut
## no critic(Subroutines::ProhibitUnusedPrivateSubroutine)
sub _validate_oligo {
    my ( $self, $oligo_data, $oligo_type, $oligo_slice ) = @_;
    $self->log->debug( "$oligo_type oligo, id: " . $oligo_data->{id} );

    $self->check_oligo_sequence( $oligo_data, $oligo_slice ) or return;
    $self->check_oligo_length( $oligo_data )                 or return;
    #TODO fix this check sp12 Tue 10 Sep 2013 09:07:52 BST
    #if ( $oligo_type =~ /5R|EF|ER|3F/ ) {
        #$self->check_oligo_not_near_exon( $oligo_data, $oligo_slice ) or return;
    #}

    #exonerate check, probably replace this
    $self->check_oligo_specificity(
        $oligo_data->{id},
        $self->exonerate_matches->{ $oligo_data->{id} }
    ) or return;

    return 1;
}
## use critic

=head2 check_oligo_not_near_exon

Check that the oligo is not within a certain number of bases of a exon

Not sure this belongs here, should either check before we invoke design creation
that the oligo candidate regions are valid, or validate the design after it is
created.

=cut
sub check_oligo_not_near_exon {
    my ( $self, $oligo_data, $oligo_slice  ) = @_;

    return 1 if $self->exon_check_flank_length == 0;

    my $expanded_slice
        = $oligo_slice->expand( $self->exon_check_flank_length, $self->exon_check_flank_length );

    my $exons = $expanded_slice->get_all_Exons;
    #TODO must avoid counting critical exon here sp12 Tue 20 Aug 2013 08:36:39 BST
    #TODO only care about coding exons? sp12 Wed 21 Aug 2013 15:06:31 BST

    # if no exons in slice we pass the check
    return 1 unless @{ $exons };

    my $exon_ids = join( ', ', map { $_->stable_id } @{$exons} );
    $self->log->debug(
        'Oligo ' . $oligo_data->{id} . " overlaps or is too close to exon(s): $exon_ids" );

    return 0;
}

sub validate_oligo_pairs {
    my $self = shift;

    for my $oligo_pair_region ( qw( exon five_prime three_prime ) ) {
        my $oligo_pair_file
            = $self->get_file( $oligo_pair_region . '_oligo_pairs.yaml', $self->oligo_finder_output_dir );

        my $oligo_pairs = LoadFile( $oligo_pair_file );
        DesignCreate::Exception->throw("No oligo pair data in $oligo_pair_file")
            unless $oligo_pairs;

        for my $pair ( @{ $oligo_pairs } ) {
            next if any{ $self->oligo_is_invalid( $_ ) } values %{ $pair };

            push @{ $self->validated_oligo_pairs->{ $oligo_pair_region } }, $pair;
        }
    }

    return;
}

sub output_valid_oligo_pairs {
    my $self = shift;

    for my $oligo_pair_region ( qw( exon five_prime three_prime ) ) {
        DesignCreate::Exception->throw( "No valid oligo pairs for $oligo_pair_region oligo region" )
            unless $self->region_has_oligo_pairs( $oligo_pair_region );

        #TODO if we add ranking of oligos this needs to use that sp12 Mon 09 Sep 2013 08:48:03 BST
        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_pair_region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_valid_pairs( $oligo_pair_region ) );
    }

    return;
}

# EXONERATE
# PROBABLY REPLACE WITH BWA?

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
    documentation => "Target file for exonerate ( defaults to species genome )",
    cmd_flag      => 'exonerate-target-file',
    predicate     => 'has_exonerate_target_file',
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
    # a hit is above 90% similarity
    elsif ( $match_info->{hits} > 1 ) {
        $self->log->info( 'Oligo ' . $oligo_id
            . ' is invalid, has multiple hits: ' . $match_info->{hits} );
        return;
    }

    #TODO add ranking of oligo here sp12 Mon 09 Sep 2013 08:48:24 BST

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
        target_file          => $self->exonerate_target_file->stringify,
        query_file           => $self->exonerate_query_file->stringify,
        percentage_hit_match => 90,
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
        for my $oligo ( @{ $self->all_oligos->{$oligo_type} } ) {
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

    $self->exonerate_target_file( $GENOME_FILES{ $self->design_param( 'species' ) } );
    return;
}

1;

__END__
