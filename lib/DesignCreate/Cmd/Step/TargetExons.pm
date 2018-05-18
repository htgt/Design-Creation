package DesignCreate::Cmd::Step::TargetExons;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::TargetExons::VERSION = '0.047';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::TargetExons - Work out target region coordiantes for given exon(s)

=head1 DESCRIPTION

Generate a yaml file giving coordinates of the target exon(s).

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::TargetExons';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->target_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate target coordinates:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
