package DesignCreate::Action::PickGapOligos;

=head1 NAME

DesignCreate::Action::PickGapOligos - Pick the best Gap oligo pair, G5 & G3

=head1 DESCRIPTION

Pick the best pair of gap oligos ( one G5 and one G3 oligo ).
Look at the sequence similarity between each combination pair of G5 and G3
and pick the ones with no matching sections of sequence.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::PickGapOligos';

#TODO move this to somewhere global
const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->pick_gap_oligos;

    return;
}

# if running command by itself we want to check the validate oligo dir exists
# default is to delete and re-create folder
override _build_validated_oligo_dir => sub {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME );
    unless ( $self->dir->contains( $validated_oligo_dir ) ) {
        $self->log->logdie( "Can't find validated oligo file dir: "
                           . $self->validated_oligo_dir->stringify );
    }

    return $validated_oligo_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
