package DesignCreate::Exception::NonExistantAttribute;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Exception::NonExistantAttribute::VERSION = '0.006';
}
## use critic


use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'Attribute not found'
);

has attribute_name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has class => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

override as_string => sub {
    my $self = shift;

    my $str = 'Attribute ' . $self->attribute_name . ' does not exist in class ' . $self->class;

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
