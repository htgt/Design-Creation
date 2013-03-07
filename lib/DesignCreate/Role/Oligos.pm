package DesignCreate::Role::Oligos;

=head1 NAME

DesignCreate::Role::Oligos

=head1 DESCRIPTION

Common Oligo attributes and methods

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( ArrayRefOfOligos );
use namespace::autoclean;

has expected_oligos => (
    is         => 'ro',
    isa        => ArrayRefOfOligos,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_expected_oligos {
    my $self = shift;

    if ( $self->design_method eq 'deletion' || $self->design_method eq 'insertion' ) {
        return [ qw( G5 U5 D3 G3 ) ];
    }
    elsif ( $self->design_method eq 'conditional' ) {
        return [ qw( G5 U5 U3 D5 D3 G3 ) ];
    }
    else {
        DesignCreate::Exception->throw( 'Unknown design method ' . $self->design_method );
    }

    return;
}

1;

__END__
