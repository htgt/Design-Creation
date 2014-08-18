package DesignCreate::Cmd::Step::FetchOligoRegionsSequence;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::FetchOligoRegionsSequence::VERSION = '0.028';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::FetchOligoRegionsSequence - Fetch sequence for oligo target regions

=head1 DESCRIPTION

Given a file specifying the coordinates of oligo regions produce fasta sequence files
for each of the oligo regions.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::FetchOligoRegionsSequence';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->create_oligo_region_sequence_files;
    }
    catch{
        $self->log->error( "Error fetching oligo region sequence files:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
