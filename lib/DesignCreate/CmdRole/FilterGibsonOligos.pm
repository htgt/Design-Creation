package DesignCreate::CmdRole::FilterGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FilterGibsonOligos::VERSION = '0.010';
}
## use critic


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
use Const::Fast;
use Fcntl; # O_ constants
use List::MoreUtils qw( any );
use namespace::autoclean;

with qw(
DesignCreate::Role::FilterOligos
);

const my @DESIGN_PARAMETERS => qw(
exon_check_flank_length
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
    if ( $oligo_type =~ /5R|EF|ER|3F/ ) {
        $self->check_oligo_not_near_exon( $oligo_data, $oligo_slice ) or return;
    }

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

        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_pair_region . '_oligo_pairs.yaml';
        DumpFile( $filename, $self->get_valid_pairs( $oligo_pair_region ) );
    }

    return;
}

1;

__END__
