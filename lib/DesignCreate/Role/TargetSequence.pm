package DesignCreate::Role::TargetSequence;

=head1 NAME

DesignCreate::Role::TargetSequence

=head1 DESCRIPTION

Attributes required to grab the sequence for the design target from Ensembl.

=cut

use Moose::Role;
use DesignCreate::Types qw( Chromosome Strand Species );
use Const::Fast;
use namespace::autoclean;

with 'DesignCreate::Role::EnsEMBL';

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

1;

__END__
