package DesignCreate::Action::RunAOS;

=head1 NAME

DesignCreate::Action::RunAOS - A wrapper around AOS

=head1 DESCRIPTION

Wrapper around AOS ( ArrayOligoSelector ).

AOS Inputs:

Files: ( fasta )
Query Sequence file
Target Sequence file

Parameters:
Minimum GC content
Oligo Length
Number of Oligos
Mask by lower case? - yes / no
Method to identify genomic origin - blat / blast / gfclient

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::RunAOS';

#TODO move this
const my $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME => 'oligo_target_regions';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->run_aos;

    return;
}

# if running command by itself we want to check the target regions dir exists
# default is to delete and re-create folder
override _build_oligo_target_regions_dir => sub {
    my $self = shift;

    my $target_regions_dir = $self->dir->subdir( $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME );
    unless ( $self->dir->contains( $target_regions_dir ) ) {
        $self->log->logdie( "Can't find aos output dir: "
                           . $target_regions_dir->stringify );
    }

    return $target_regions_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
