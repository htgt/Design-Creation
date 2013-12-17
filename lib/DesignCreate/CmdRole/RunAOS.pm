package DesignCreate::CmdRole::RunAOS;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::RunAOS::VERSION = '0.014';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::RunAOS - A wrapper around AOS

=head1 DESCRIPTION

Wrapper around AOS ( ArrayOligoSelector ).

AOS Inputs:

Files: ( fasta )
Query Sequence file
Target Sequence file

Parameters:
Minimum GC content
Oligo Length
Number of Oligos
Mask by lower case? - yes / no
Method to identify genomic origin - blat / blast / gfclient

=cut

use Moose::Role;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use namespace::autoclean;

with 'DesignCreate::Role::AOS';

has query_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    required      => 1,
    documentation => 'The fasta file containing the query sequence',
    cmd_flag      => 'query-file'
);

has target_file => (
    is            => 'ro',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    required      => 1,
    documentation => 'The fasta file containing the target sequence',
    cmd_flag      => 'target-file'
);

1;

__END__
