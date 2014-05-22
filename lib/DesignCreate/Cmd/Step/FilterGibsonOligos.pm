package DesignCreate::Cmd::Step::FilterGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::FilterGibsonOligos::VERSION = '0.026';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::FilterGibsonOligos - Filter out invalid oligos for gibson designs

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::FilterGibsonOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->filter_oligos;
    }
    catch{
        $self->log->error( "Error filtering oligos:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
