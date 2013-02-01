package DesignCreate::Role::AOSParameters;

=head1 NAME

DesignCreate::Role::AOSParameters

=head1 DESCRIPTION

Some common parameters required to run AOS, all have solid defaults.

The query and target file parameters are not specified here,
but in RunAOS.pm as FindOligos.pm calls RunAOS and must specify or
generate these files dynamically.

=cut

use Moose::Role;
use Const::Fast;
use namespace::autoclean;

const my $DEFAULT_AOS_LOCATION => '/nfs/users/nfs_s/sp12/workspace/ArrayOligoSelector';

has aos_location => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    default       => sub{ Path::Class::Dir->new( $DEFAULT_AOS_LOCATION )->absolute },
    documentation => "Location of AOS scripts ( default $DEFAULT_AOS_LOCATION )",
    cmd_flag      => 'aos-location'
);

has oligo_length => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Length of the oligos AOS is to find ( default 50 )',
    default       => 50,
    cmd_flag      => 'oligo-length',
);

has num_oligos => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Number of oligos AOS finds for each query sequence ( default 3 )',
    default       => 3,
    cmd_flag      => 'num-oligos',
);

has minimum_gc_content => (
    is            => 'ro',
    isa           => 'Int',
    traits        => [ 'Getopt' ],
    documentation => 'Minumum GC content of oligos ( default 28 )',
    default       => 28,
    cmd_flag      => 'min-gc-content',
);

has mask_by_lower_case => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Should AOS mask lowercase sequence in its calculations ( default no )',
    default       => 'no',
    cmd_flag      => 'mask-by-lower-case',
);

has genomic_search_method => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'Method AOS uses to identify genomic origin, options: blat or blast ( default blat )',
    default       => 'blat',
    cmd_flag      => 'genomic-search-method',
);

1;

__END__
