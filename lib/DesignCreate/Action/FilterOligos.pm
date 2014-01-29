package DesignCreate::Action::FilterOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::FilterOligos::VERSION = '0.017';
}
## use critic


=head1 NAME

DesignCreate::Action::FilterOligos - Filter out invalid oligos

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

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FilterOligos';

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

# if running command by itself we want to check the oligo finder output dir exists
# default is to delete and re-create folder
override _build_oligo_finder_output_dir => sub {
    my $self = shift;

    my $oligo_finder_output_dir = $self->dir->subdir( $self->oligo_finder_output_dir_name );
    unless ( $self->dir->contains( $oligo_finder_output_dir ) ) {
        $self->log->logdie( "Can't find oligo finder output dir: "
                           . $oligo_finder_output_dir->stringify );
    }

    return $oligo_finder_output_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
