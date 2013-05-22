package DesignCreate::Action::FindOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::FindOligos::VERSION = '0.008';
}
## use critic


=head1 NAME

DesignCreate::Action::FindOligos - Get oligos for a design

=head1 DESCRIPTION

Finds a selection of oligos for a design given the oligos target ( candidate ) regions.
This is a wrapper around RunAOS which does the real work.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FindOligos';

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

# if running command by itself we want to check the target regions dir exists
# default is to delete and re-create folder
override _build_oligo_target_regions_dir => sub {
    my $self = shift;

    my $target_regions_dir = $self->dir->subdir( $self->oligo_target_regions_dir_name );
    unless ( $self->dir->contains( $target_regions_dir ) ) {
        $self->log->logdie( "Can't find aos output dir: "
                           . $target_regions_dir->stringify );
    }

    return $target_regions_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
