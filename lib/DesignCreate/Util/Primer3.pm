package DesignCreate::Util::Primer3;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Util::Primer3::VERSION = '0.022';
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
use DesignCreate::Exception::Primer3RunFail;
use Bio::Tools::Primer3Redux;
use Bio::Tools::Run::Primer3Redux;
use DesignCreate::Types qw( PositiveInt NaturalNumber);
use Const::Fast;
use Try::Tiny;
use Scalar::Util qw( blessed reftype );
use DesignCreate::Constants qw( $PRIMER3_CMD );
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
    'primer_opt_tm',
    'primer_max_tm',
    'primer_min_tm',
    'primer_lowercase_masking',
    'primer_explain_flag',
    'primer_min_three_prime_distance',
    'primer_product_size_range',
    'primer_thermodynamic_parameters_path',
    'primer_gc_clamp',
);

has [
    'primer_num_return',
    'primer_min_size',
    'primer_max_size',
    'primer_opt_size',
    'primer_opt_gc_percent',
    'primer_max_gc',
    'primer_min_gc',
    'primer_opt_tm',
    'primer_max_tm',
    'primer_min_tm',
] => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

has 'primer_gc_clamp' => (
    is       => 'ro',
    isa      => NaturalNumber,
    default  => 0,
    lazy     => 1,
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
    my ( $self, $outfile, $seq, $target, $region ) = @_;
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
        -path    => $PRIMER3_CMD,
    );
    DesignCreate::Exception->throw( "primer3 can not be found" )
        unless $primer3->executable;

    $primer3->set_parameters( %{ $self->primer3_global_arguments } );

    # Setup specific target which primers must flank
    if ( $target && exists $target->{SEQUENCE_TARGET} ) {
        $self->log->debug('Specify target primers must flank: ' . $target->{SEQUENCE_TARGET} );
        $primer3->set_parameters( SEQUENCE_TARGET => $target->{SEQUENCE_TARGET} );
    }

    my $results;
    try{
        $results = $primer3->pick_pcr_primers( $seq );
    }
    catch {
        $self->log->debug( "Error running primer3: $_" );
        my $primer3_explain = $self->parse_primer_explain_details( $outfile );
        DesignCreate::Exception::Primer3RunFail->throw(
            region        => $region,
            primer3_error => $primer3_explain->{PRIMER_ERROR},
        );
    };
    # we are only sending in one sequence so we will only have one result
    my $result = $results->next_result;

    my $primer3_explain = $self->parse_primer_explain_details( $outfile );

    if ( $result->warnings ) {
        $self->log->warn( "Primer3 warning: $_" ) for $result->warnings;
    };

    if ( $result->errors ) {
        $self->log->error( "Primer3 error: $_" ) for $result->errors;
        return;
    };

    return ( $result, $primer3_explain );
}

=head2 parse_primer_explain_details

Parse out the details of the left and right primer explain flags from primer3 log output.
This gives details on how many potential primers there were and the numbers that were excluded.

=cut
sub parse_primer_explain_details {
    my ( $self, $outfile  ) = @_;
    my %primer3_explain;

    my @output = $outfile->slurp;
    chomp(@output);
    ## no critic(RegularExpressions::ProhibitComplexRegexes)
    my @explain_data = grep{ /^PRIMER_(LEFT|RIGHT)_EXPLAIN=|^SEQUENCE_TEMPLATE=|^PRIMER_ERROR=/ } @output;
    ## use critic

    %primer3_explain = map{ split /=/ } @explain_data;

    return \%primer3_explain;
}

1;

__END__
