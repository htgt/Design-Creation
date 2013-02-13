package DesignCreate::Action::FilterOligos;

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
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FilterOligos';

#TODO move this
const my $DEFAULT_AOS_OUTPUT_DIR_NAME => 'aos_output';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->filter_oligos;

    return;
}

# if running command by itself we want to check the aos output dir exists
# default is to delete and re-create folder
override _build_aos_output_dir => sub {
    my $self = shift;

    my $aos_output_dir = $self->dir->subdir( $DEFAULT_AOS_OUTPUT_DIR_NAME );
    unless ( $self->dir->contains( $aos_output_dir ) ) {
        $self->log->logdie( "Can't find aos output dir: "
                           . $aos_output_dir->stringify );
    }

    return $aos_output_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
