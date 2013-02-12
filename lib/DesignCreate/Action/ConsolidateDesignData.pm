package DesignCreate::Action::ConsolidateDesignData;

=head1 NAME

DesignCreate::Action::ConsolidateDesignData - Bring together all the design data into one file

=head1 DESCRIPTION

Create one yaml file containing all the data for one design:
Target
Species
Phase
Design Type
Created By
Oligos

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::ConsolidateDesignData';

#TODO move this to somewhere global
const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->consolidate_design_data;

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
