package DesignCreate::Role::Oligos;

=head1 NAME

DesignCreate::Role::Oligos

=head1 DESCRIPTION

Common Oligo attributes and methods

=cut

use Moose::Role;
use DesignCreate::Types qw( ArrayRefOfOligos );
use namespace::autoclean;

has expected_oligos => (
    is         => 'ro',
    isa        => ArrayRefOfOligos,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

#TODO account for all design type
sub _build_expected_oligos {
    my $self = shift;

    if ( $self->design_method eq 'deletion' ) {
        return [ qw( G5 U5 D3 G3 ) ];
    }
    else {
        die( 'Unknown design method ' . $self->design_method );
    }
}

1;

__END__
