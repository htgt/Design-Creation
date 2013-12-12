package DesignCreate::Action::FindGibsonOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::FindGibsonOligos::VERSION = '0.012';
}
## use critic


=head1 NAME

DesignCreate::Action::FindGibsonOligos - Get oligos for a gibson design

=head1 DESCRIPTION

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
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
