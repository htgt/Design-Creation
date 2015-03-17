package DesignCreate::Cmd::Step::ConsolidateDesignData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::ConsolidateDesignData::VERSION = '0.035';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::ConsolidateDesignData - Bring together all the design data into one file

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
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::ConsolidateDesignData';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->consolidate_design_data;
    }
    catch{
        $self->log->error( "Unable to consolidate design data:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
