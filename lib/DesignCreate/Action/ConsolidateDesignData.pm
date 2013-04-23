package DesignCreate::Action::ConsolidateDesignData;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::ConsolidateDesignData::VERSION = '0.004';
}
## use critic


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
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
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
