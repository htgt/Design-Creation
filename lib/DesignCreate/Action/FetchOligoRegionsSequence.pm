package DesignCreate::Action::FetchOligoRegionsSequence;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::FetchOligoRegionsSequence::VERSION = '0.006';
}
## use critic


=head1 NAME

DesignCreate::Action::FetchOligoRegionsSequence - Fetch sequence for oligo target regions

=head1 DESCRIPTION

Given a file specifying the coordinates of oligo regions produce fasta sequence files
for each of the oligo regions.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FetchOligoRegionsSequence';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->create_oligo_region_sequence_files;
    }
    catch{
        $self->log->error( "Error fetching oligo region sequence files:\n" . $_ );
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
