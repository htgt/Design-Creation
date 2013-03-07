package DesignCreate::CmdRole::PickBlockOligos;

=head1 NAME

DesignCreate::CmdRole::PickBlockOligos - Pick the best U and D block oligo pairs

=head1 DESCRIPTION

Pick the best pair of block oligos ( U5 & U3, D5 & D3 ).
Pair must be a minimum distance apart.
Best pair has smallest distance seperating them, that is bigger than the minimum distance.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Types qw( PositiveInt );
use YAML::Any qw( DumpFile );
use DesignCreate::Util::PickBlockOligoPair;
use namespace::autoclean;

with qw(
DesignCreate::Role::TargetSequence
);

# Don't need the following attributes when running this command on its own
__PACKAGE__->meta->remove_attribute( 'chr_name' );
__PACKAGE__->meta->remove_attribute( 'species' );

has min_U_oligo_gap => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Minimum gap between U oligos',
    required      => 1,
    cmd_flag      => 'min-U-oligo-gap',
);

has min_D_oligo_gap => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Minimum gap between D oligos',
    required      => 1,
    cmd_flag      => 'min-D-oligo-gap',
);

sub pick_block_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->pick_block_oligo_pair( $_ ) for qw( U D );

    return;
}

sub pick_block_oligo_pair {
    my ( $self, $oligo_type ) = @_;

    my $min_gap_attribute = 'min_' . $oligo_type . '_oligo_gap';
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $min_gap_attribute,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($min_gap_attribute);

    my $five_prime_oligo_file = $self->get_file( $oligo_type . '5.yaml' , $self->validated_oligo_dir );
    my $three_prime_oligo_file = $self->get_file( $oligo_type . '3.yaml', $self->validated_oligo_dir );

    my $oligo_picker = DesignCreate::Util::PickBlockOligoPair->new(
        five_prime_oligo_file  => $five_prime_oligo_file,
        three_prime_oligo_file => $three_prime_oligo_file,
        strand                 => $self->chr_strand,
        min_gap                => $self->$min_gap_attribute,
    );

    my $oligo_pairs = $oligo_picker->get_oligo_pairs;
    DesignCreate::Exception->throw( "No valid oligo pairs for $oligo_type oligo region" )
        unless @{ $oligo_pairs };

    my $oligo_pair_file =  $self->validated_oligo_dir->file( $oligo_type . '_oligo_pairs.yaml');
    DumpFile( $oligo_pair_file, $oligo_pairs );
    $self->log->info( "Picked $oligo_type oligo pairs" );

    return;
}

1;

__END__
