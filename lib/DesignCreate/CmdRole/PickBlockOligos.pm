package DesignCreate::CmdRole::PickBlockOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::PickBlockOligos::VERSION = '0.024';
}
## use critic


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
use DesignCreate::Constants qw( $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME );
use YAML::Any qw( DumpFile );
use DesignCreate::Util::PickBlockOligoPair;
use Const::Fast;
use Fcntl; # O_ constants
use namespace::autoclean;

const my @DESIGN_PARAMETERS => qw(
min_U_oligo_gap
min_D_oligo_gap
);

has min_U_oligo_gap => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Minimum gap between U oligos, optional',
    cmd_flag      => 'min-U-oligo-gap',
);

has min_D_oligo_gap => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Minimum gap between D oligos, optional',
    cmd_flag      => 'min-D-oligo-gap',
);

has block_oligo_log_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_block_oligo_log_dir {
    my $self = shift;

    my $dir = $self->validated_oligo_dir->subdir( $DEFAULT_BLOCK_OLIGO_LOG_DIR_NAME )->absolute;
    $dir->rmtree();
    $dir->mkpath();

    return $dir;
}

sub pick_block_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
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

    my $five_prime_oligo_file
        = $self->get_file( $oligo_type . '5.yaml', $self->validated_oligo_dir );
    my $three_prime_oligo_file
        = $self->get_file( $oligo_type . '3.yaml', $self->validated_oligo_dir );

    my $oligo_picker = DesignCreate::Util::PickBlockOligoPair->new(
        five_prime_oligo_file  => $five_prime_oligo_file,
        three_prime_oligo_file => $three_prime_oligo_file,
        strand                 => $self->design_param( 'chr_strand' ),
        min_gap                => $self->$min_gap_attribute,
    );

    my $oligo_pairs = $oligo_picker->get_oligo_pairs;
    DesignCreate::Exception->throw( "No valid oligo pairs for $oligo_type oligo region" )
        unless @{ $oligo_pairs };

    #Log output
    my $block_pick_output = $self->block_oligo_log_dir->file( $oligo_type . '_block_pick.log');
    my $fh = $block_pick_output->open( O_WRONLY|O_CREAT )
        or die( "Open $block_pick_output: $!" );
    print $fh $oligo_picker->join_output_log( "\n" );

    my $oligo_pair_file =  $self->validated_oligo_dir->file( $oligo_type . '_oligo_pairs.yaml');
    DumpFile( $oligo_pair_file, $oligo_pairs );
    $self->log->info( "Picked $oligo_type oligo pairs" );

    return;
}

1;

__END__
