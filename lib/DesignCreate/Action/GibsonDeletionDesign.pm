package DesignCreate::Action::GibsonDeletionDesign;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::GibsonDeletionDesign::VERSION = '0.018';
}
## use critic


=head1 NAME

DesignCreate::Action::GibsonDeletionDesign - Run design creation for gibson deletion design on exon(s)

=head1 DESCRIPTION

Runs all the seperate steps used to create a gibson deletion design on specified exon(s).
Persists the design to LIMS2 if persist option given.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use Data::Dump qw( pp );
use Scalar::Util 'blessed';
use JSON;
use YAML::Any qw( DumpFile );

extends qw( DesignCreate::Action );
with qw(
DesignCreate::CmdRole::OligoPairRegionsGibsonDel
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

# wipe work directory before starting
has '+rm_dir' => (
    default => 1,
);

sub execute {
    my ( $self, $opts, $args ) = @_;
    Log::Log4perl::NDC->push( @{ $self->target_genes }[0] );
    my $exon_string = $self->five_prime_exon;
    $exon_string .= '-' . $self->three_prime_exon if $self->three_prime_exon;
    Log::Log4perl::NDC->push( $exon_string );

    $self->log->info( 'Starting new gibson deletion design create run: ' . join(',', @{ $self->target_genes } ) );
    $self->log->debug( 'Design run args: ' . pp($opts) );
    $self->create_design_attempt_record;

    try {
        $self->get_oligo_pair_region_coordinates;
        $self->find_oligos;
        $self->filter_oligos;
        $self->consolidate_design_data;
        $self->persist_design if $self->persist;
        $self->log->info( 'DESIGN DONE: ' . join(',', @{ $self->target_genes } ) );

        $self->update_design_attempt_record(
            {   status => 'success',
                design_ids => join( ' ', @{ $self->design_ids } ),
            }
        );
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
