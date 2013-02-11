package DesignCreate::Action::RunAOS;

=head1 NAME

DesignCreate::Action::RunAOS - A wrapper around AOS

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

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::RunAOS';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->run_aos;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
