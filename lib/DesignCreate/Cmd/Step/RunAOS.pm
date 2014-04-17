package DesignCreate::Cmd::Step::RunAOS;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::RunAOS::VERSION = '0.024';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::RunAOS - A wrapper around AOS

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
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::RunAOS';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->run_aos;
    }
    catch{
        $self->log->error( "Error running aos:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
