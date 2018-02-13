package DesignCreate::Exception::OligoValidation;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Exception::OligoValidation::VERSION = '0.046';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'Failed to find any valid oligos for one or more oligo types'
);

has oligo_types => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
);

# $reason{'region'}{'left'}
has invalid_reasons => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

override as_string => sub {
    my $self = shift;

    my $str = 'Failed to find any valid oligos of types: ' . join(',', @{ $self->oligo_types } );

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

around as_hash => sub {
    my $orig = shift;
    my $self = shift;

    my $hash = $self->$orig;

    $hash->{oligo_Types} = $self->oligo_types;
    $hash->{reasons} = $self->invalid_reasons;

    return $hash;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
