package DesignCreate::Action::FilterOligos;

=head1 NAME

DesignCreate::Action::FilterOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use DesignCreate::Types qw( PositiveInt Chromosome Strand Species );
use DesignCreate::Util::Exonerate;
use YAML::Any qw( LoadFile DumpFile );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use namespace::autoclean;

const my $DEFAULT_AOS_OLIGO_DIR_NAME => 'aos_output';
const my $DEFAULT_EXONERATE_OLIGO_DIR_NAME => 'exonerate_oligos';
const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';

extends qw( DesignCreate::Action );

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
    documentation => "Target file for AOS, defaults to chromosome sequence of design target",
    cmd_flag      => 'exonerate-target-file',
    predicate     => 'has_exonerate_target_file',
);

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target',
    required      => 1,
    default       => 'mouse',
);

has chr_name => (
    is            => 'ro',
    isa           => Chromosome,
    traits        => [ 'Getopt' ],
    documentation => 'Name of chromosome the design target lies within',
    required      => 1,
    cmd_flag      => 'chromosome'
);

has chr_strand => (
    is            => 'ro',
    isa           => Strand,
    traits        => [ 'Getopt' ],
    documentation => 'The strand the design target lies on',
    required      => 1,
    cmd_flag      => 'strand'
);

has flank_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Number of bases to either side of G5 and G3 where we check for oligo specificity',
    cmd_flag      => 'flank-length',
    default       => 100000
);

has aos_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the oligo yaml files'
                     . " defaults to [design_dir]/$DEFAULT_AOS_OLIGO_DIR_NAME",
    coerce        => 1,
    lazy_build    => 1,
    cmd_flag      => 'aos-oligo-dir',
);

sub _build_aos_oligo_dir {
    my $self = shift;

    return $self->dir->subdir( $DEFAULT_AOS_OLIGO_DIR_NAME )->absolute;
}

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

has validated_oligo_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME )->absolute;
    $validated_oligo_dir->rmtree();
    $validated_oligo_dir->mkpath();

    return $validated_oligo_dir;
}

has oligo_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Length of the oligos AOS is to find ( default 50 )',
    default       => 50,
    required      => 1,
    cmd_flag      => 'oligo-length',
);

has oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

has validated_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

use Smart::Comments;

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->validate_oligos or return;

    $self->check_specificity_of_oligos or return;

    $self->output_validated_oligos;

    return;
}

#Validate oligo coordinates, sequence and length
sub validate_oligos {
    my $self = shift;

    for my $oligo_type ( @{ $self->expected_oligos } ) {
        my $oligo_file = $self->aos_oligo_dir->file( $oligo_type . '.yaml' );
        unless ( $self->aos_oligo_dir->contains( $oligo_file ) ) {
            $self->log->error("Can't find $oligo_type oligo file: $oligo_file");
            return;
        }

        unless ( $self->validate_oligos_of_type( $oligo_file, $oligo_type ) ) {
            $self->log->error("No valid $oligo_type oligos");
            return;
        }
        $self->log->info("We have $oligo_type oligos that pass initial checks");
    }

    return 1;
}

sub validate_oligos_of_type {
    my ( $self, $oligo_file, $oligo_type ) = @_;
    $self->log->debug( "Validating $oligo_type oligos" );

    my $oligos = LoadFile( $oligo_file );
    unless ( @{ $oligos } ) {
        $self->log->logdie( "No oligo data in $oligo_file for $oligo_type oligo" );
    }

    my $valid_oligos = 0;
    for my $oligo_data ( @{ $oligos } ) {
        if ( $self->validate_oligo( $oligo_data, $oligo_type ) ) {
            push @{ $self->oligos->{$oligo_type} }, $oligo_data;
        }
    }

    unless ( @{ $self->oligos->{$oligo_type} } ) {
        $self->log->error("No valid $oligo_type oligos");
    }

    return 1;
}

sub validate_oligo {
    my ( $self, $oligo_data, $oligo_type ) = @_;
    $self->log->debug( "$oligo_type oligo, offset: " . $oligo_data->{offset} );

    if ( !defined $oligo_data->{oligo} || $oligo_data->{oligo} ne $oligo_type )   {
        $self->log->error("Oligo name mismatch, expecting $oligo_type, got: " . $oligo_data->{oligo} );
        return;
    }

    $self->check_oligo_coordinates( $oligo_data ) or return;
    $self->check_oligo_sequence( $oligo_data ) or return;
    $self->check_oligo_length( $oligo_data ) or return;

    return 1;
}

sub check_oligo_coordinates {
    my ( $self, $oligo_data ) = @_;

    if ( $oligo_data->{oligo_start} != ( $oligo_data->{target_region_start} + $oligo_data->{offset} ) ) {
        $self->log->error('Oligo start coordinates incorrect');
        return 0;
    }

    if ( $oligo_data->{oligo_end} != ( $oligo_data->{oligo_start} + ( $oligo_data->{oligo_length} - 1 ) ) ) {
        $self->log->error('Oligo end coordinates incorrect');
        return 0;
    }

    $self->log->debug('Coordinates look correct');
    return 1;
}

sub check_oligo_sequence {
    my ( $self, $oligo_data ) = @_;

    my $ensembl_seq = $self->get_sequence( $oligo_data->{oligo_start}, $oligo_data->{oligo_end} );

    if ( $ensembl_seq ne $oligo_data->{oligo_seq} ) {
        $self->log->error( 'Oligo seq does not match coordinate sequence' );
        return 0;
    }

    $self->log->debug('Sequence for coordinates matches oligo sequence');
    return 1;
}

sub check_oligo_length {
    my ( $self, $oligo_data ) = @_;

    my $oligo_length = length($oligo_data->{oligo_seq});
    if ( $oligo_length != $self->oligo_length ) {
        $self->log->error("Oligo length is $oligo_length, should be " . $self->oligo_length );
        return 0;
    }

    $self->log->debug('Oligo length correct');
    return 1;
}

sub check_specificity_of_oligos {
    my $self = shift;

    $self->define_exonerate_query_file;
    $self->define_exonerate_target_file;

    my $exonerate_matches = $self->run_exonerate;

    return unless $exonerate_matches;

    # go through output and filter out oligos that are not specific enough
    $self->filter_out_non_specific_oligos( $exonerate_matches );

    for my $oligo_type ( @{ $self->expected_oligos } ) {
        unless ( exists $self->validated_oligos->{$oligo_type} ) {
            $self->log->warn( "No valid $oligo_type oligos, halting filter process" );
            return;
        }
    }

    return 1;
}

sub filter_out_non_specific_oligos {
    my ( $self, $matches ) = @_;

    for my $oligo_type ( keys %{ $self->oligos } ) {

        for my $oligo ( @{ $self->oligos->{$oligo_type} } ) {
            my $match_info = $matches->{ $oligo->{id} };

            if ( !$match_info->{exact_matches} ) {
                $self->log->error( 'Oligo ' . $oligo->{id} . ' does not have any exact matches, somethings wrong ' );
                next;
            }
            elsif ( $match_info->{exact_matches} > 1 ) {
                $self->log->info( 'Oligo ' . $oligo->{id} . ' is invalid, has multiple exact matches: ' . $match_info->{exact_matches} );
                next;
            }
            # hit is above 80% similarity
            elsif ( $match_info->{hits} > 1 ) {
                $self->log->info( 'Oligo ' . $oligo->{id} . ' is invalid, has multiple hits: ' . $match_info->{hits} );
                next;
            }
            #its ok
            push @{ $self->validated_oligos->{$oligo_type} }, $oligo;
        }

    }

    return;
}

sub run_exonerate {
    my $self = shift;

    # now run exonerate
    my $exonerate = DesignCreate::Util::Exonerate->new(
        target_file => $self->exonerate_target_file->stringify,
        query_file  => $self->exonerate_query_file->stringify,
    );

    my $output = $exonerate->run_exonerate;
    # put exonerate output in a log file
    my $exonerate_output = $self->exonerate_oligo_dir->file('exonerate_output.log');
    my $fh = $exonerate_output->open( O_WRONLY|O_CREAT ) or die( "Open $exonerate_output: $!" );
    print $fh $output;

    my $matches = $exonerate->parse_exonerate_output;
    unless ( %{ $matches } ) {
        $self->log->error("No output from exonerate");
        return;
    }

    return $matches;
}

sub define_exonerate_query_file {
    my $self = shift;

    my $query_file = $self->exonerate_oligo_dir->file('exonerate_query.fasta');
    my $fh         = $query_file->open( O_WRONLY|O_CREAT ) or die( "Open $query_file: $!" );
    my $seq_out    = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo_type ( keys %{ $self->oligos } ) {
        for my $oligo ( @{ $self->oligos->{$oligo_type} } ) {
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

    my $target_seq = $self->get_sequence( $self->target_flanking_region_coordinates );

    my $bio_seq  = Bio::Seq->new( -seq => $target_seq, -id => 'exonerate_target_sequence' );
    $seq_out->write_seq( $bio_seq );

    $self->log->debug("Created exonerate target file $target_file");
    $self->exonerate_target_file( $target_file );
    return;
}

#TODO this will need to be strand dependant
sub target_flanking_region_coordinates {
    my $self = shift;

    my $g5_region_start = $self->oligos->{'G5'}[0]{target_region_start};
    my $g3_region_end   = $self->oligos->{'G3'}[0]{target_region_end};

    my $flanking_region_start = $g5_region_start - $self->flank_length;
    my $flanking_region_end = $g3_region_end + $self->flank_length;

    return( $flanking_region_start, $flanking_region_end );
}

sub output_validated_oligos {
    my $self = shift;

    for my $oligo_type ( keys %{ $self->validated_oligos } ) {
        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_type . '.yaml';
        DumpFile( $filename, $self->validated_oligos->{$oligo_type} );
    }
}

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
