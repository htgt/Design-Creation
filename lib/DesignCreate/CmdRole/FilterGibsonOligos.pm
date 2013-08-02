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
use DesignCreate::Types qw( PositiveInt );
use Const::Fast;
use Fcntl; # O_ constants
use List::MoreUtils qw( any );
use namespace::autoclean;

with qw(
DesignCreate::Role::EnsEMBL
);

const my @DESIGN_PARAMETERS => qw(
exon_check_flank_length
);

has exon_check_flank_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => "Number of flanking bases surrounding middle oligos to check for exons",
    cmd_flag      => 'exon-check-flank-length',
    default       => 100,
);

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

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

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

    my $oligo_slice = $self->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $self->design_param( 'chr_name' ),
    );

    $self->check_oligo_sequence( $oligo_data, $oligo_slice ) or return;
    $self->check_oligo_length( $oligo_data ) or return;
    if ( $oligo_type =~ /5R|EF|ER|3F/ ) {
        $self->check_oligo_not_near_exon( $oligo_data, $oligo_slice ) or return;
    }

    return 1;
}

sub check_oligo_sequence {
    my ( $self, $oligo_data, $oligo_slice ) = @_;

    if ( $oligo_slice->seq ne uc( $oligo_data->{oligo_seq} ) ) {
        $self->log->error( 'Oligo seq does not match coordinate sequence: ' . $oligo_data->{id} );
        $self->log->trace( 'Oligo seq  : ' . $oligo_data->{oligo_seq} );
        $self->log->trace( "Ensembl seq: " . $oligo_slice->seq );
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

=head2 check_oligo_not_near_exon

Check that the oligo is not within a certain number of bases of a exon

Not sure this belongs here, should either check before we invoke design creation
that the oligo candidate regions are valid, or validate the design after it is
created.

=cut
sub check_oligo_not_near_exon {
    my ( $self, $oligo_data, $oligo_slice  ) = @_;

    my $expanded_slice
        = $oligo_slice->expand( $self->exon_check_flank_length, $self->exon_check_flank_length );

    my $exons = $expanded_slice->get_all_Exons;

    # if no exons in slice we pass the check
    return 1 unless @{ $exons };

    my $exon_ids = join( ', ', map { $_->stable_id } @{$exons} );
    $self->log->debug(
        'Oligo ' . $oligo_data->{id} . " overlaps or is too close to exon(s): $exon_ids" );

    return 0;
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
