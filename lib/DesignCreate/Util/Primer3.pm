package DesignCreate::Util::Primer3;

use Moose;
use namespace::autoclean;
use Bio::Tools::Primer3Redux;
use Bio::Tools::Run::Primer3Redux;
use DesignCreate::Types qw( PositiveInt );
use Const::Fast;
use Scalar::Util qw( blessed reftype );

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

#TODO make isa Booleon sp12 Wed 17 Jul 2013 14:05:50 BST
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

#TODO add logging sp12 Thu 18 Jul 2013 10:49:36 BST
sub run_primer3 {
    my ( $self, $outfile, $seq, $target ) = @_;

    #TODO throw exceptions sp12 Thu 18 Jul 2013 10:49:20 BST
    if ( ! blessed( $outfile ) || ! $outfile->isa( 'Path::Class::File' ) ) {
        die( 'Outfile variable  must be Path::Class::File object' );
    }
    if ( ! blessed( $seq ) || ! $seq->isa( 'Bio::SeqI' ) ) {
        die( 'Sequence variable must be Bio::SeqI object' );
    }
    if ( $target && reftype $target ne 'HASH' ) {
        die( 'Target variable must be a hashref or undef' );
    }

    my $primer3 = Bio::Tools::Run::Primer3Redux->new(
        -outfile => $outfile->stringify,
        -path    => $self->primer3_path
    );
    die( "primer3 can not be found" ) unless $primer3->executable;

    $primer3->set_parameters( %{ $self->primer3_global_arguments } );

    # Setup specific target which primers must flank
    if ( $target && exists $target->{SEQUENCE_TARGET} ) {
        $primer3->set_parameters( SEQUENCE_TARGET => $target->{SEQUENCE_TARGET} );
    }

    my $results = $primer3->pick_pcr_primers( $seq );
    my $result = $results->next_result;
    unless ( $result ) {
        die( "No results returned from primer3" );
    }

    return $result;
}

1;

__END__
