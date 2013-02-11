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
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::ConsolidateDesignData';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->consolidate_design_data;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
