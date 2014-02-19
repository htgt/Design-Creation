package DesignCreate::Action::PickBlockOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::PickBlockOligos::VERSION = '0.021';
}
## use critic


=head1 NAME

DesignCreate::Action::PickBlockOligos - Pick the best U and D block oligo pairs

=head1 DESCRIPTION

Pick the best pair of block oligos ( U5 & U3, D5 & D3 ).
Must have a minumum gap between the oligo pairs.
We prefer closer pairs of oligos.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::PickBlockOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->pick_block_oligos;
    }
    catch{
        $self->log->error( "Error picking block oligos:\n" . $_ );
    };

    return;
}

# if running command by itself we want to check the validate oligo dir exists
# default is to delete and re-create folder
override _build_validated_oligo_dir => sub {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $self->validated_oligo_dir_name );
    unless ( $self->dir->contains( $validated_oligo_dir ) ) {
        $self->log->logdie( "Can't find validated oligo file dir: "
                           . $validated_oligo_dir->stringify );
    }

    return $validated_oligo_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
