package DesignCreate::Exception::MissingFile;

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'File not found'
);

has dir => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has file => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);


override as_string => sub {
    my $self = shift;

    my $str = 'Cannot find file ' . $self->file->basename . ' in directory ' . $self->dir->stringify;

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;