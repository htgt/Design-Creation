package DesignCreate::Util::PickBlockOligoPair;

=head1 NAME

DesignCreate::Util::PickBlockOligos - Pick the best block oligo pair

=head1 DESCRIPTION

Pick the best pair of oligos from a block region.
Pair must be a minimum distance apart.
Best pair has smallest distance seperating them, that is bigger than the minimum distance.

=cut

use Moose;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt Strand );
use YAML::Any qw( LoadFile );
use namespace::autoclean;

with qw( MooseX::Log::Log4perl );

has five_prime_oligo_file => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has three_prime_oligo_file => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has min_gap => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

has strand => (
    is       => 'ro',
    isa      => Strand,
    required => 1,
);

has left_oligos => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

sub _build_left_oligos {
    my $self = shift;

    my $oligo_file = $self->strand == 1 ? $self->five_prime_oligo_file : $self->three_prime_oligo_file;
    return LoadFile( $oligo_file );
}

has right_oligos => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

sub _build_right_oligos {
    my $self = shift;

    my $oligo_file = $self->strand == 1 ? $self->three_prime_oligo_file : $self->five_prime_oligo_file;
    return LoadFile( $oligo_file );
}

has oligo_region_length => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
);

sub _build_oligo_region_length {
    my $self = shift;

    my $start = $self->left_oligos->[0]{target_region_start};
    my $end   = $self->right_oligos->[0]{target_region_end};

    return ( $end - $start ) + 1;
}

has optimal_gap_length => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
);

# Optimal gap length is 15% of the total oligo region length
sub _build_optimal_gap_length {
    my $self = shift;
    my $optimal_gap_length = $self->oligo_region_length * 0.15;

    return sprintf("%d" , $optimal_gap_length );
}

has oligo_pairs => (
    is      => 'ro',
    isa     => 'ArrayRef',
    traits  => [ 'Array' ],
    default => sub{ [] },
    handles => {
        add_oligo_pair   => 'push',
        sort_oligo_pairs => 'sort_in_place',
        have_oligo_pairs => 'count',
    },
);

has pick_log => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [ 'Array' ],
    default => sub{ [] },
    handles => {
        add_log         => 'push',
        join_output_log => 'join',
    },
);

sub get_oligo_pairs {
    my $self = shift;

    for my $left_oligo ( @{ $self->left_oligos } ) {
        for my $right_oligo ( @{ $self->right_oligos } ) {
            $self->check_oligo_pair( $left_oligo, $right_oligo );
        }
    }

    # Order from closest to ideal gap to furthest away
    # If minimum gap specified this will still do the right thing
    $self->sort_oligo_pairs( sub{ $_[0]->{optimal_gap_diff} <=> $_[1]->{optimal_gap_diff} } );

    return $self->oligo_pairs;
}

## no critic(ValuesAndExpressions::ProhibitCommanSeperatedStatements)
sub check_oligo_pair {
    my ( $self, $left_oligo, $right_oligo ) = @_;

    DesignCreate::Exception->throw(
        'Invalid input ' . $left_oligo->{id} . ' and '
        . $right_oligo->{id} . ' overlap, error with input'
    ) if $left_oligo->{oligo_end} > $right_oligo->{oligo_start};

    my $oligo_gap = ( $right_oligo->{oligo_start} - $left_oligo->{oligo_end} ) - 1;
    my $log_str = $left_oligo->{id} . ' and ' . $right_oligo->{id} . " gap is $oligo_gap";

    if ( $self->min_gap && $oligo_gap < $self->min_gap ) {
        $log_str .= ' - REJECT, minimum gap is ' . $self->min_gap;
        $self->log->debug( $log_str );
    }
    else{
        $log_str .= ' - PASS';
        $self->add_oligo_pair(
            {
                $left_oligo->{oligo}  => $left_oligo->{id},
                $right_oligo->{oligo} => $right_oligo->{id},
                optimal_gap_diff      => abs( $self->optimal_gap_length - $oligo_gap ),
                oligo_gap             => $oligo_gap,
            }
        );
    }
    $self->add_log( $log_str );

    return;
}
## use critic

__PACKAGE__->meta->make_immutable;

1;

__END__
