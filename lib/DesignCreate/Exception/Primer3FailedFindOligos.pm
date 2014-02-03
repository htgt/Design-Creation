package DesignCreate::Exception::Primer3FailedFindOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Exception::Primer3FailedFindOligos::VERSION = '0.018';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'Primer3 failed to find oligos'
);

has regions => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
);

# $reason{'region'}{'left'}
has primer_fail_reasons => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

override as_string => sub {
    my $self = shift;

    my $str = 'Primer3 failed to find oligos for following regions: ' . join(',', @{ $self->regions } );

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

around as_hash => sub {
    my $orig = shift;
    my $self = shift;

    my $hash = $self->$orig;

    $hash->{regions} = $self->regions;
    $hash->{reasons} = $self->primer_fail_reasons;

    return $hash;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
