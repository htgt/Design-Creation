package DesignCreate::Role::Chromosome;

=head1 NAME

DesignCreate::Role::AOS

=head1 DESCRIPTION

=cut

use Moose::Role;
use DesignCreate::Types qw( Chromosome Strand Species );
use namespace::autoclean;

#TODO move assembly here?
# Rename
# move ensembl_util attribute here?
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
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target ( default mouse )',
    default       => 'mouse',
);

#TODO: check valid sequence found
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

1;

__END__
