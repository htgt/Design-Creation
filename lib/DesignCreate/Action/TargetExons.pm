package DesignCreate::Action::TargetExons;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::TargetExons::VERSION = '0.020';
}
## use critic


=head1 NAME

DesignCreate::Action::TargetExons - Work out target region coordiantes for given exon(s)

=head1 DESCRIPTION

Generate a yaml file giving coordinates of the target exon(s).

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
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
