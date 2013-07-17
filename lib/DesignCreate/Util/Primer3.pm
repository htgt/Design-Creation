package DesignCreate::Util::Primer3;

use Moose;
use namespace::autoclean;
use Bio::Tools::Primer3Redux;
use Bio::Tools::Run::Primer3Redux;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt );
use Const::Fast;

with qw( MooseX::Log::Log4perl MooseX::SimpleConfig );

const my @PRIMER3_ARGUMENTS => (
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

# modify to work relative to WORK_DIR
has outfile => (
    is       => 'ro',
    isa      => AbsFile,
    coerce   => 1,
    required => 1,
);

has seq => (
    is       => 'ro',
    isa      => 'Bio::SeqI',
    required => 1,
);

# Number of bases target region starts from the start of the sequence
has target_region_start_offset => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

# Number of bases target region ends from the end of the sequence
has target_region_end_offset => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
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
    isa      => 'Int',
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

has primer3_arguments => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1
);

sub _build_primer3_arguments {
    my $self = shift;
    my %primer3_arguments;

    foreach (@PRIMER3_ARGUMENTS) {
        $primer3_arguments{ uc($_) } = $self->$_ if $self->$_;
    }

    return \%primer3_arguments;
}

#
#Run Primer3 with passed in arguments and targetting information from
#the PrimerTarget object
#
sub run_primer3 {
    my $self = shift;

    my $primer3 = Bio::Tools::Run::Primer3Redux->new(
        -seq     => $self->seq,
        -outfile => $self->outfile,
        -path    => $self->primer3_path
    );
    
    unless ($primer3->executable) {
        die( "primer3 can not be found");
    }

    $primer3->set_parameters( %{ $self->primer3_arguments } );

    #CUSTOM
    my $length = $self->seq->length;
    $primer3->set_parameters( SEQUENCE_TARGET => $self->target_region_start_offset . ','
            . ( $length - $self->target_region_end_offset - $self->target_region_start_offset ) );


    my $results = $primer3->pick_pcr_primers( $self->seq );
    my $result = $results->next_result;
    unless ( $result ) {
        die( "No results returned from primer3" );
    }

    return $result;
}

1;

__END__
