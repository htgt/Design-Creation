package DesignCreate::Action::InsDelDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::InsDelDesign::VERSION = '0.014';
}
## use critic


=head1 NAME

DesignCreate::Action::InsDelDesign - Run design creation for Ins / Del designs end to end

=head1 DESCRIPTION

Runs all the seperate steps used to create a Insertion of Deletion design.
Persists the design to LIMS2 if persist option given.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );

extends qw( DesignCreate::Action );
with qw(
DesignCreate::CmdRole::OligoRegionsInsDel
DesignCreate::CmdRole::FetchOligoRegionsSequence
DesignCreate::CmdRole::FindOligos
DesignCreate::CmdRole::FilterOligos
DesignCreate::CmdRole::PickGapOligos
DesignCreate::CmdRole::ConsolidateDesignData
DesignCreate::CmdRole::PersistDesign
);

has persist => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist design to LIMS2',
    default       => 0
);

# Turn off the following attributes command line option attribute
# these values should be set when running the design creation process
# end to end
const my @ATTRIBUTES_NO_CMD_OPTION => qw(
target_file
exonerate_target_file
design_data_file
validated_oligo_dir
oligo_finder_output_dir
oligo_target_regions_dir
aos_location
base_chromosome_dir
genomic_search_method
);

for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
}

# wipe work directory before starting
has '+rm_dir' => (
    default => 1,
);

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );

    $self->log->info( 'Starting new ins-del design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );
    $self->create_design_attempt_record;

    try {
        $self->get_oligo_region_coordinates;
        $self->create_oligo_region_sequence_files;
        $self->find_oligos;
        $self->filter_oligos;
        $self->pick_gap_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );
    }
    catch {
        if (blessed($_) and $_->isa('DesignCreate::Exception')) {
            DumpFile( $self->design_fail_file, $_->as_hash );
            $self->update_design_attempt_record(
                {   status => 'fail',
                    fail   => encode_json( $_->as_hash ),
                }
            );
        }
        else {
            $self->update_design_attempt_record(
                {   status => 'error',
                    error => $_,
                }
            );
        }
        $self->log->error( 'DESIGN INCOMPLETE: ' . $_ );
    };

    Log::Log4perl::NDC->remove;
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
