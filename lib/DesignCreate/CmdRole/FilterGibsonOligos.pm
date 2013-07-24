package DesignCreate::CmdRole::FilterGibsonOligos;

=head1 NAME

DesignCreate::CmdRole::FilterGibsonOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt );
use DesignCreate::Util::Exonerate;
use DesignCreate::Exception;
use YAML::Any qw( LoadFile DumpFile );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use Bio::SeqIO;
use Try::Tiny;
use List::MoreUtils qw( any );
use namespace::autoclean;

with qw(
DesignCreate::Role::EnsEMBL
);

const my $DEFAULT_EXONERATE_OLIGO_DIR_NAME => 'exonerate_oligos';

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

has all_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

has invalid_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt', 'Hash' ],
    default => sub { {  } },
    handles => {
        add_invalid_oligo   => 'set',
        oligo_is_invalid    => 'exists',
        have_invalid_oligos => 'count',
    }
);

has exonerate_matches => (
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

    #$self->add_design_parameters( \@DESIGN_PARAMETERS );

    $self->validate_oligos;
    $self->have_required_validated_oligos;
    #$self->run_exonerate;
    #$self->filter_out_non_specific_oligos;
    $self->output_validated_oligos;
    $self->validate_oligo_pairs;
    $self->output_valid_oligo_pairs;

    return;
}

#Validate oligo coordinates, sequence and length
sub validate_oligos {
    my $self = shift;

    for my $oligo_type ( $self->expected_oligos ) {
        my $oligo_file = $self->get_file( "$oligo_type.yaml", $self->oligo_finder_output_dir );

        DesignCreate::Exception->throw("No valid $oligo_type oligos")
            unless $self->validate_oligos_of_type( $oligo_file, $oligo_type );

        $self->log->info("We have $oligo_type oligos that pass initial checks");
    }

    return 1;
}

sub validate_oligos_of_type {
    my ( $self, $oligo_file, $oligo_type ) = @_;
    $self->log->debug( "Validating $oligo_type oligos" );

    my $oligos = LoadFile( $oligo_file );
    unless ( $oligos ) {
        $self->log->error( "No oligo data in $oligo_file for $oligo_type oligo" );
        return;
    }

    # for now push straight into validated_oligos hash, bypass all_oligos
    # we will change this is we need to exonerate oligos
    for my $oligo_data ( @{ $oligos } ) {
        if ( $self->validate_oligo( $oligo_data, $oligo_type ) ) {
            push @{ $self->validated_oligos->{$oligo_type} }, $oligo_data
        }
        else {
            $self->add_invalid_oligo( $oligo_data->{id} => 1 );
        }
    }

    unless ( exists $self->validated_oligos->{$oligo_type} ) {
        $self->log->error("No valid $oligo_type oligos");
        return;
    }

    return 1;
}

sub validate_oligo {
    my ( $self, $oligo_data, $oligo_type ) = @_;
    $self->log->debug( "$oligo_type oligo, id: " . $oligo_data->{id} );

    if ( !defined $oligo_data->{oligo} || $oligo_data->{oligo} ne $oligo_type )   {
        $self->log->error("Oligo name mismatch, expecting $oligo_type, got: "
            . $oligo_data->{oligo} . 'for: ' . $oligo_data->{id} );
        return;
    }

    #TODO check all but the 2 outer oligos are not near exons ( 100 bases ) sp12 Wed 24 Jul 2013 09:56:47 BST
    $self->check_oligo_sequence( $oligo_data ) or return;
    $self->check_oligo_length( $oligo_data ) or return;

    return 1;
}

sub check_oligo_sequence {
    my ( $self, $oligo_data ) = @_;

    my $ensembl_slice = $self->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $self->design_param( 'chr_name' ),
    );

    if ( $ensembl_slice->seq ne uc( $oligo_data->{oligo_seq} ) ) {
        $self->log->error( 'Oligo seq does not match coordinate sequence: ' . $oligo_data->{id} );
        $self->log->trace( 'Oligo seq  : ' . $oligo_data->{oligo_seq} );
        $self->log->trace( "Ensembl seq: " . $ensembl_slice->seq );
        return 0;
    }

    $self->log->debug('Sequence for coordinates matches oligo sequence: ' . $oligo_data->{id} );
    return 1;
}

sub check_oligo_length {
    my ( $self, $oligo_data ) = @_;

    my $oligo_length = length($oligo_data->{oligo_seq});
    if ( $oligo_length != $oligo_data->{oligo_length} ) {
        $self->log->error("Oligo length is $oligo_length, should be "
                           . $oligo_data->{oligo_length} . ' for: ' . $oligo_data->{id} );
        return 0;
    }

    $self->log->debug('Oligo length correct for: ' . $oligo_data->{id} );
    return 1;
}

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
    if ( $strand == 1 ) {
        $start = $self->all_oligos->{'G5'}[0]{target_region_start};
        $end   = $self->all_oligos->{'G3'}[0]{target_region_end};
    }
    else {
        $start = $self->all_oligos->{'G3'}[0]{target_region_start};
        $end   = $self->all_oligos->{'G5'}[0]{target_region_end};
    }

    my $flanking_region_start = $start - $self->flank_length;
    my $flanking_region_end = $end + $self->flank_length;

    return( $flanking_region_start, $flanking_region_end, $self->design_param( 'chr_name' ) );
}

sub filter_out_non_specific_oligos {
    my ( $self ) = @_;

    for my $oligo_type ( $self->expected_oligos ) {
        for my $oligo ( @{ $self->all_oligos->{$oligo_type} } ) {
            next unless my $match_info = $self->exonerate_matches->{ $oligo->{id} };
            next unless $self->check_oligo_specificity( $oligo->{id}, $match_info );

            push @{ $self->validated_oligos->{$oligo_type} }, $oligo;
        }
    }

    return;
}

sub check_oligo_specificity {
    my ( $self, $oligo_id, $match_info ) = @_;

    if ( !$match_info->{exact_matches} ) {
        $self->log->error( 'Oligo ' . $oligo_id
            . ' does not have any exact matches, somethings wrong ' );
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

# go through output and filter out oligos that are not specific enough
sub have_required_validated_oligos {
    my $self = shift;

    for my $oligo_type ( $self->expected_oligos ) {
        DesignCreate::Exception->throw( "No valid $oligo_type oligos, halting filter process" )
            unless exists $self->validated_oligos->{$oligo_type};
    }

    return 1;
}

sub output_validated_oligos {
    my $self = shift;

    for my $oligo_type ( keys %{ $self->validated_oligos } ) {
        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_type . '.yaml';
        DumpFile( $filename, $self->validated_oligos->{$oligo_type} );
    }

    return;
}

sub validate_oligo_pairs {
    my $self = shift;

    #TODO if not invalid oligos sp12 Wed 24 Jul 2013 08:26:44 BST
    # if there are not invalid oligos then all the pairs of valid 
    # we can just copy the files over from one folder to another
    #return unless $self->have_invalid_oligos;

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

        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_pair_region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_valid_pairs( $oligo_pair_region ) );
    }
}

1;

__END__