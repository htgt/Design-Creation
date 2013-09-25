package DesignCreate::Util::Primer3;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Util::Primer3::VERSION = '0.011';
}
## use critic


=head1 NAME

DesignCreate::Util::Primer3 -Wrapper around Primer3

=head1 DESCRIPTION

Wrapper around Primer3 primer finding application.
Actually it uses Bio::Tools::Primer3Redux, which itself calls Primer3

=cut

use Moose;
use DesignCreate::Exception;
use Bio::Tools::Primer3Redux;
use Bio::Tools::Run::Primer3Redux;
use DesignCreate::Types qw( PositiveInt );
use Const::Fast;
use Scalar::Util qw( blessed reftype );
use namespace::autoclean;

with qw( MooseX::Log::Log4perl MooseX::SimpleConfig );

const my @PRIMER3_GLOBAL_ARGUMENTS => (
    'primer_num_return',
    'primer_min_size',
    'primer_max_size',
    'primer_opt_size',
    'primer_opt_gc_percent',
    'primer_max_gc',
    'primer_min_gc',
    'primer_lowercase_masking',
    'primer_explain_flag',
    'primer_min_three_prime_distance',
    'primer_product_size_range',
    'primer_thermodynamic_parameters_path',
);

#TODO change path to primer3 sp12 Wed 17 Jul 2013 10:13:33 BST
has primer3_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => '/nfs/users/nfs_s/sp12/workspace/primer3-2.3.5/src/primer3_core',
);

has [
    'primer_num_return',
    'primer_min_size',
    'primer_max_size',
    'primer_opt_size',
    'primer_opt_gc_percent',
    'primer_max_gc',
    'primer_min_gc',
] => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

has [
    'primer_lowercase_masking',
    'primer_explain_flag',
] => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

has primer_thermodynamic_parameters_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has primer_product_size_range  => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has primer_min_three_prime_distance => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
) ;

has primer3_global_arguments => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1
);

sub _build_primer3_global_arguments {
    my $self = shift;
    my %primer3_arguments;

    foreach (@PRIMER3_GLOBAL_ARGUMENTS) {
        $primer3_arguments{ uc($_) } = $self->$_ if $self->$_;
    }

    return \%primer3_arguments;
}

#
#Run Primer3 with passed in arguments and targetting information from
#the PrimerTarget object
#

sub run_primer3 {
    my ( $self, $outfile, $seq, $target ) = @_;
    $self->log->debug( 'Running Primer3' );

    if ( ! blessed( $outfile ) || ! $outfile->isa( 'Path::Class::File' ) ) {
        DesignCreate::Exception->throw( '$outfile variable must be Path::Class::File object' );
    }
    if ( ! blessed( $seq ) || ! $seq->isa( 'Bio::SeqI' ) ) {
        DesignCreate::Exception->throw( '$seq variable must be Bio::SeqI object' );
    }
    if ( $target && reftype $target ne 'HASH' ) {
        DesignCreate::Exception->throw( '$target variable must be a hashref or undef' );
    }

    my $primer3 = Bio::Tools::Run::Primer3Redux->new(
        -outfile => $outfile->stringify,
        -path    => $self->primer3_path
    );
    DesignCreate::Exception->throw( "primer3 can not be found" )
        unless $primer3->executable;

    $primer3->set_parameters( %{ $self->primer3_global_arguments } );

    # Setup specific target which primers must flank
    if ( $target && exists $target->{SEQUENCE_TARGET} ) {
        $self->log->debug('Specify target primers must flank: ' . $target->{SEQUENCE_TARGET} );
        $primer3->set_parameters( SEQUENCE_TARGET => $target->{SEQUENCE_TARGET} );
    }

    my $results = $primer3->pick_pcr_primers( $seq );
    # we are only sending in one sequence so we will only have one result
    my $result =  $results->next_result;

    if ( $result->warnings ) {
        $self->log->warn( "Primer3 warning: $_" ) for $result->warnings;
    };

    if ( $result->errors ) {
        $self->log->error( "Primer3 error: $_" ) for $result->errors;
        return;
    };

    return $result;
}

1;

__END__
