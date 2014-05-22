package DesignCreate::CmdRole::PickGapOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::PickGapOligos::VERSION = '0.026';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::PickGapOligos - Pick the best Gap oligo pair, G5 & G3

=head1 DESCRIPTION

Pick the best pair of gap oligos ( one G5 and one G3 oligo ).
Look at the sequence similarity between each combination pair of G5 and G3
and pick the ones with no matching sections of sequence.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Constants qw( $DEFAULT_GAP_OLIGO_LOG_DIR_NAME );
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( PositiveInt );
use List::MoreUtils qw( all );
use Data::Dump qw( pp );
use Const::Fast;
use namespace::autoclean;

const my @DESIGN_PARAMETERS => qw(
tile_size
);

has g5_oligos_data => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    traits     => [ 'NoGetopt', 'Hash' ],
    handles => {
        g5_oligo_ids => 'keys',
        g5_oligos    => 'values',
    },
);

sub _build_g5_oligos_data {
    my $self = shift;

    my $g5_oligos_file = $self->get_file( "G5.yaml", $self->validated_oligo_dir );
    my $data = LoadFile( $g5_oligos_file );

    return { map{ $_->{id} => $_ } @{ $data } };
}

has g3_oligos_data => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    traits     => [ 'NoGetopt', 'Hash' ],
    handles => {
        g3_oligo_ids => 'keys',
        g3_oligos    => 'values',
    },
);

sub _build_g3_oligos_data {
    my $self = shift;

    my $g3_oligos_file = $self->get_file( "G3.yaml", $self->validated_oligo_dir );
    my $data = LoadFile( $g3_oligos_file );

    return { map{ $_->{id} => $_ } @{ $data } };
}

has gap_oligo_log_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_gap_oligo_log_dir {
    my $self = shift;

    my $dir = $self->validated_oligo_dir->subdir( $DEFAULT_GAP_OLIGO_LOG_DIR_NAME )->absolute;
    $dir->rmtree();
    $dir->mkpath();

    return $dir;
}

has tile_size => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Size of tiling when matching G oligos ( default 6 )',
    cmd_flag      => 'tile-size',
    default       => 6,
);

has tiled_oligo_seqs => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { { } },
);

has matching_oligos => (
    is     => 'rw',
    isa    => 'HashRef',
    traits => [ 'NoGetopt' ],
);

has oligo_pairs => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [ 'NoGetopt', 'Array' ],
    default => sub { [] },
    handles => {
        add_oligo_pair => 'push',
        no_oligo_pairs => 'is_empty',
    }
);

sub pick_gap_oligos {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->generate_tiled_oligo_seqs;
    $self->find_oligos_with_matching_seqs;
    $self->get_gap_oligo_pairs;
    $self->create_oligo_pair_file;

    return;
}

sub generate_tiled_oligo_seqs {
    my $self = shift;

    foreach my $oligo ( $self->g5_oligos, $self->g3_oligos ) {
        $self->tile_oligo_seq( $oligo );
    }
    $self->log->debug('Generated tiled oligo sequence hash');
    DumpFile( $self->gap_oligo_log_dir->file('tiled_oligo_seqs.yaml'), $self->tiled_oligo_seqs );

    return;
}

sub tile_oligo_seq {
    my ( $self, $oligo ) = @_;
    my $oligo_seq = $oligo->{oligo_seq};

    for (
        my $start = 0;
        $start < ( 1 + length($oligo_seq) - $self->tile_size );
        $start++
        )
    {
        my $subseq = substr( $oligo_seq, $start, $self->tile_size );
        $self->tiled_oligo_seqs->{ $subseq }{ $oligo->{id} }++;
    }

    return;
}

sub find_oligos_with_matching_seqs {
    my $self = shift;
    my %matching_oligos;

    for my $oligo_matches ( values %{ $self->tiled_oligo_seqs } ) {
        my @oligos = keys %{ $oligo_matches };

        # only want seqs which belong to 2 or more oligos
        next if scalar( @oligos ) == 1;
        # if seqs only belong to one type of oligo we are not interested
        next if all{ /G5/ } @oligos;
        next if all{ /G3/ } @oligos;

        foreach my $g5_oligo_name ( grep{ /G5/} @oligos ) {
            foreach my $g3_oligo_name ( grep{ /G3/ } @oligos ) {
                $matching_oligos{$g5_oligo_name}{$g3_oligo_name}++;
            }
        }
    }

    $self->log->debug('Generated matching oligos hash');
    DumpFile( $self->gap_oligo_log_dir->file('matching_oligos.yaml'), \%matching_oligos );

    $self->matching_oligos( \%matching_oligos );
    return;
}

sub get_gap_oligo_pairs {
    my $self = shift;

    for my $g5_oligo ( $self->g5_oligo_ids ) {
        if ( !exists $self->matching_oligos->{$g5_oligo} ) {
            $self->add_oligo_pair( map { { G5 => $g5_oligo, G3 => $_ } } $self->g3_oligo_ids );
            next;
        }

        for my $g3_oligo ( $self->g3_oligo_ids ) {
            $self->add_oligo_pair( { G5 => $g5_oligo, G3 => $g3_oligo } )
                if !exists $self->matching_oligos->{$g5_oligo}{$g3_oligo};
        }
    }

    $self->log->info( 'Found G oligo pairs: ' . pp($self->oligo_pairs) );
    return;
}

sub create_oligo_pair_file {
    my $self = shift;

    DesignCreate::Exception->throw('No suitable gap oligo pairs found')
        if $self->no_oligo_pairs;

    my $oligo_pair_file =  $self->validated_oligo_dir->file('G_oligo_pairs.yaml');
    DumpFile( $oligo_pair_file, $self->oligo_pairs );

    return;
}

1;

__END__
