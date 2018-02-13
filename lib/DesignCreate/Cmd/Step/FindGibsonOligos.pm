package DesignCreate::Cmd::Step::FindGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::FindGibsonOligos::VERSION = '0.046';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::FindGibsonOligos - Get oligos for a gibson design

=head1 DESCRIPTION

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::FindGibsonOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->find_oligos;
    }
    catch{
        $self->log->error( "Error finding oligos:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
