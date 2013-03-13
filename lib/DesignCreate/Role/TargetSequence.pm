package DesignCreate::Role::TargetSequence;

=head1 NAME

DesignCreate::Role::TargetSequence

=head1 DESCRIPTION

Attributes required to grab the sequence for the design target from Ensembl.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( Chromosome Strand Species );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

const my $CURRENT_ASSEMBLY => 'GRCm38';

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

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'NoGetopt' ],
    documentation => 'The species of the design target ( default Mouse )',
    default       => 'Mouse',
);

has assembly => (
    is      => 'ro',
    isa     => 'Str',
    traits  => [ 'NoGetopt' ],
    default => sub { $CURRENT_ASSEMBLY },
);

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

sub get_sequence {
    my ( $self, $start, $end ) = @_;

    my $slice = $self->_get_sequence( $start, $end );

    return $slice->seq;
}

sub get_repeat_masked_sequence {
    my ( $self, $start, $end ) = @_;

    my $slice = $self->_get_sequence( $start, $end );

    # softmasked
    my $repeat_masked_slice = $slice->get_repeatmasked_seq( undef , 1 );

    return $repeat_masked_slice->seq;
}

sub _get_sequence {
    my ( $self, $start, $end ) = @_;

    my $slice;

    $self->log->logdie( 'Start must be less than end' )
        if $start > $end;

    # We always get sequence on the +ve strand
    try{
        $slice = $self->slice_adaptor->fetch_by_region(
            'chromosome',
            $self->chr_name,
            $start,
            $end,
        );
    }
    catch{
        DesignCreate::Exception->throw( 'Error fetching Ensembl slice: ' . $_ );
    };

    return $slice;
}

1;

__END__
