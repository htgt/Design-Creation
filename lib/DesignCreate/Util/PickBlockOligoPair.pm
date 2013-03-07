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
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
);

has strand => (
    is       => 'ro',
    isa      => Strand,
    required => 1,
);

has left_oligo_data => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
    traits     => [ 'Array' ],
    handles    => {
        sort_left_oligos => 'sort_in_place',
        left_oligos      => 'elements',
    },
);

sub _build_left_oligo_data {
    my $self = shift;

    my $oligo_file = $self->strand == 1 ? $self->five_prime_oligo_file : $self->three_prime_oligo_file;
    return LoadFile( $oligo_file );
}

has right_oligo_data => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
    traits     => [ 'Array' ],
    handles    => {
        sort_right_oligos => 'sort_in_place',
        right_oligos      => 'elements',
    },
);

sub _build_right_oligo_data {
    my $self = shift;

    my $oligo_file = $self->strand == 1 ? $self->three_prime_oligo_file : $self->five_prime_oligo_file;
    return LoadFile( $oligo_file );
}

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

# left oligos ranked from closest to 3' end to furthest
# right oligos ranked from cloesest to 5' end to furthest
# subroutine will list pairs from closest together to furthest apart
sub get_oligo_pairs {
    my $self = shift;
    my @oligo_pairs;

    # rank right oligos from closest to 5' to furthest
    $self->sort_right_oligos( sub{ $_[0]->{offset} <=> $_[1]->{offset} } );
    # rank left oligos from closest to 3' to furthest
    $self->sort_left_oligos( sub{ $_[1]->{offset} <=> $_[0]->{offset} } );

    for my $left_oligo ( $self->left_oligos ) {
        for my $right_oligo ( $self->right_oligos ) {
            $self->check_oligo_pair( $left_oligo, $right_oligo, \@oligo_pairs );
        }
    }

    return \@oligo_pairs;
}

sub check_oligo_pair {
    my ( $self, $left_oligo, $right_oligo, $oligo_pairs ) = @_;

    DesignCreate::Exception->throw(
        'Invalid input ' . $left_oligo->{id} . ' and '
        . $right_oligo->{id} . ' overlap, error with input'
    ) if $left_oligo->{oligo_end} > $right_oligo->{oligo_start};

    my $oligo_gap = ( $right_oligo->{oligo_start} - $left_oligo->{oligo_end} ) - 1;
    my $log_str = $left_oligo->{id} . ' and ' . $right_oligo->{id} . " gap is $oligo_gap";

    if ( $oligo_gap < $self->min_gap ) {
        $log_str .= ' - REJECT, minimum gap is ' . $self->min_gap;
        $self->log->debug( $log_str );
    }
    else {
        $log_str .= ' - PASS';
        push @{ $oligo_pairs }, {
            $left_oligo->{oligo}  => $left_oligo->{id},
            $right_oligo->{oligo} => $right_oligo->{id}
        };
    }
    $self->add_log( $log_str );

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
