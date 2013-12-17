package DesignCreate::CmdRole::FindOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::FindOligos::VERSION = '0.015';
}
## use critic


=head1 NAME

DesignCreate::Action::FindOligos - Get oligos for a design

=head1 DESCRIPTION

Finds a selection of oligos for a design given the oligos target ( candidate ) regions.
This is a wrapper around RunAOS which does the real work.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Constants qw( %DEFAULT_CHROMOSOME_DIR );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Bio::SeqIO;
use Bio::Seq;
use Fcntl; # O_ constants
use Const::Fast;
use Try::Tiny;
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::AOS
);

requires qw(
oligo_target_regions_dir
oligo_finder_output_dir
);

const my @DESIGN_PARAMETERS => qw(
oligo_length
num_oligos
minimum_gc_content
mask_by_lower_case
genomic_search_method
);

has query_file => (
    is         => 'ro',
    isa        => AbsFile,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_query_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( 'all_target_regions.fasta' );

    return $file;
}

has repeat_masked_oligo_regions => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    traits  => [ 'NoGetopt', 'Array' ],
    handles => {
        add_repeat_masked_oligo_region   => 'push',
        has_repeat_masked_oligo_regions  => 'count',
        list_repeat_masked_oligo_regions => 'join',
    },
);

has target_file => (
    is            => 'rw',
    isa           => AbsFile,
    traits        => [ 'Getopt' ],
    coerce        => 1,
    documentation => "Target file for AOS ( defaults to chromosome sequence of design )",
    cmd_flag      => 'target-file',
    predicate     => 'has_user_defined_target_file',
);

has base_chromosome_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    coerce        => 1,
    lazy_build    => 1,
    documentation => "Location of chromosome files",
    cmd_flag      => 'base-chromosome-dir'
);

sub _build_base_chromosome_dir {
    my $self = shift;

    my $species = $self->design_param( 'species' );
    my $assembly = $self->design_param( 'assembly' );
    my $dir = Path::Class::Dir->new( $DEFAULT_CHROMOSOME_DIR{ $species }{ $assembly } );

    return $dir->absolute;
}

sub find_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->create_aos_query_file;
    $self->define_target_file;
    $self->run_aos;
    $self->check_aos_output;

    return;
}

# put all oligo target regions in one query file and run that
sub create_aos_query_file {
    my $self = shift;

    my $fh = $self->query_file->open( O_WRONLY|O_CREAT )
        or die( $self->query_file->stringify . " open failure: $!" );

    my $seq_out = Bio::SeqIO->new( -fh => $fh, -format => 'fasta' );

    for my $oligo ( $self->expected_oligos ) {
        my $oligo_file = $self->get_file( "$oligo.fasta", $self->oligo_target_regions_dir );

        my $seq_in = Bio::SeqIO->new( -fh => $oligo_file->openr, -format => 'fasta' );
        $self->log->debug( "Adding $oligo oligo target sequence to query file" );

        while ( my $seq_obj = $seq_in->next_seq ) {
            $self->check_masked_seq( $seq_obj->seq, $oligo ) if $self->mask_by_lower_case eq 'yes';
            $seq_out->write_seq( $seq_obj );
        }
    }

    if ( $self->has_repeat_masked_oligo_regions ) {
        DesignCreate::Exception->throw(
            'Following oligo regions are completely repeat masked: '
            . $self->list_repeat_masked_oligo_regions( ',' )
        );
    }

    $self->log->debug('AOS query file created: ' . $self->query_file->stringify );

    return;
}

#check if entire region is repeat masked
sub check_masked_seq {
    my ( $self, $seq, $oligo ) = @_;

    if ( $seq =~ /^[actg]+$/ ) {
        $self->add_repeat_masked_oligo_region( $oligo );
    }

    return;
}

sub define_target_file {
    my $self = shift;

    if ( $self->has_user_defined_target_file ) {
        $self->log->debug( 'We have a user defined target file: ' . $self->target_file->stringify );
        return;
    }

    my $chr_file = $self->get_file( $self->design_param( 'chr_name' ) . ".fasta", $self->base_chromosome_dir );
    $self->log->debug( "Target file found: $chr_file" );
    $self->target_file( $chr_file );

    return;
}

sub check_aos_output {
    my $self = shift;
    my @missing_oligos;

    for my $oligo ( $self->expected_oligos ) {
        try{
            #this will throw a error if file does not exist
            $self->get_file( "$oligo.yaml", $self->oligo_finder_output_dir );
        }
        catch {
            push @missing_oligos, $oligo;
        };
    }
    DesignCreate::Exception->throw(
        "AOS was unable to find any of the following oligos: " . join( ' ', @missing_oligos )
    ) if @missing_oligos;

    $self->log->info('All oligo yaml files are present');
    return;
}

1;

__END__
