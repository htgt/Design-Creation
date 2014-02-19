package DesignCreate::Exception::Primer3RunFail;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Exception::Primer3RunFail::VERSION = '0.021';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'Primer3 failed to run'
);

has region => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has primer3_error => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

override as_string => sub {
    my $self = shift;

    my $str = "Primer3 failed to run, error: " . $self->primer3_error;

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

around as_hash => sub {
    my $orig = shift;
    my $self = shift;

    my $hash = $self->$orig;

    $hash->{reasons} = $self->primer3_error;
    $hash->{region} = $self->region;

    return $hash;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
