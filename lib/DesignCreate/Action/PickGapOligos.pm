package DesignCreate::Action::PickGapOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::PickGapOligos::VERSION = '0.015';
}
## use critic


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
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::PickGapOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->pick_gap_oligos;
    }
    catch{
        $self->log->error( "Error picking gap oligos:\n" . $_ );
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
