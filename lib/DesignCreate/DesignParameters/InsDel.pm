package DesignCreate::Role::OligoRegionParameters;

=head1 NAME

DesignCreate::Role::Deletion

=head1 DESCRIPTION

Oligo Target Region attributes for deletion type designs

=cut

#TODO setup config files to set some values below, don't use defaults

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use namespace::autoclean;

has target_start => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Start coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-start'
);

has target_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'End coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-end'
);

has G5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G5 oligo candidate region',
    cmd_flag      => 'g5-region-length'
);

has G5_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G5 oligo candidate region',
    cmd_flag      => 'g5-region-offset'
);

has U5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of U5 oligo candidate region',
    cmd_flag      => 'u5-region-length'
);

has U5_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of U5 oligo candidate region',
    cmd_flag      => 'u5-region-offset'
);

has D3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of D3 oligo candidate region',
    cmd_flag      => 'd3-region-length'
);

has D3_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of D3 oligo candidate region',
    cmd_flag      => 'd3-region-offset'
);

has G3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G3 oligo candidate region',
    cmd_flag      => 'g3-region-length'
);

has G3_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G3 oligo candidate region',
    cmd_flag      => 'g3-region-offset'
);

sub get_oligo_region_coordinates {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    # TODO make this work for all design methods, currently only works for deletion/ insertion designs
    if ( $self->chr_strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

sub get_oligo_region_offset {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_offset';
    DesignCreate::Exception->throw( "Attribute $attribute_name does not exist" )
        unless  $self->meta->has_attribute( $attribute_name );

    return $self->$attribute_name;
}

sub get_oligo_region_length {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_length';
    DesignCreate::Exception->throw( "Attribute $attribute_name does not exist" )
        unless $self->meta->has_attribute( $attribute_name );

    return $self->$attribute_name;
}

1;

__END__
