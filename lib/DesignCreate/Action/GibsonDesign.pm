package DesignCreate::Action::GibsonDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::GibsonDesign::VERSION = '0.010';
}
## use critic


=head1 NAME

DesignCreate::Action::GibsonDesign - Run design creation for gibosn design on a exon end to end

=head1 DESCRIPTION

Runs all the seperate steps used to create a gibson design on a specified exon.
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
DesignCreate::CmdRole::OligoPairRegionsGibson
DesignCreate::CmdRole::FindGibsonOligos
DesignCreate::CmdRole::FilterGibsonOligos
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
design_data_file
validated_oligo_dir
oligo_finder_output_dir
oligo_target_regions_dir
);

for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
}

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );
    Log::Log4perl::NDC->push( $self->target_exon );

    $self->log->info( 'Starting new gibson design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );

    try {
        $self->get_oligo_pair_region_coordinates;
        $self->find_oligos;
        $self->filter_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );
    }
    catch {
        $self->log->error( 'DESIGN INCOMPLETE: ' . $_ );
    };

    Log::Log4perl::NDC->remove;
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
