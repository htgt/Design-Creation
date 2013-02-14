package DesignCreate::CmdRole::PickGapOligos;

=head1 NAME

DesignCreate::CmdRole::PickGapOligos - Pick the best Gap oligo pair, G5 & G3

=head1 DESCRIPTION

Pick the best pair of gap oligos ( one G5 and one G3 oligo ).
Look at the sequence similarity between each combination pair of G5 and G3
and pick the ones with no matching sections of sequence.

=cut

use Moose::Role;
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( PositiveInt );
use List::MoreUtils qw( all );
use Data::Dump qw( pp );
use namespace::autoclean;

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

    my $g5_oligos_file = $self->validated_oligo_dir->file( 'G5.yaml' );
    unless ( $self->validated_oligo_dir->contains( $g5_oligos_file ) ) {
        $self->log->logdie( "Can't find validated G5 oligos file in dir: "
                           . $self->validated_oligo_dir->stringify );
    }

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

    my $g3_oligos_file = $self->validated_oligo_dir->file( 'G3.yaml' );
    unless ( $self->validated_oligo_dir->contains( $g3_oligos_file ) ) {
        $self->log->logdie( "Can't find validated G3 oligos file in dir: "
                           . $self->validated_oligo_dir->stringify );
    }

    my $data = LoadFile( $g3_oligos_file );

    return { map{ $_->{id} => $_ } @{ $data } };
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
    is     => 'rw',
    isa    => 'HashRef',
    traits => [ 'NoGetopt' ],
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

    $self->generate_tiled_oligo_seqs;
    $self->find_oligos_with_matching_seqs;
    $self->get_gap_oligo_pairs;
    $self->create_oligo_pair_file;

    return;
}

sub generate_tiled_oligo_seqs {
    my $self = shift;
    my %tiled_seqs;

    foreach my $oligo ( $self->g5_oligos, $self->g3_oligos ) {
        my $oligo_seq = $oligo->{oligo_seq};

        for (
            my $start = 0;
            $start < ( 1 + length($oligo_seq) - $self->tile_size );
            $start++
            )
        {
            my $subseq = substr( $oligo_seq, $start, $self->tile_size );
            $tiled_seqs{ $subseq }{ $oligo->{id} }++;
        }
    }
    $self->log->debug('Generated tiled oligo sequence hash');
    DumpFile( $self->validated_oligo_dir->file('tiled_oligo_seqs.yaml'), \%tiled_seqs );

    $self->tiled_oligo_seqs( \%tiled_seqs );
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
    DumpFile( $self->validated_oligo_dir->file('matching_oligos.yaml'), \%matching_oligos );

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

    $self->log->info( 'Found oligo pairs: ' . pp($self->oligo_pairs) );
    return;
}

sub create_oligo_pair_file {
    my $self = shift;

    if ( $self->no_oligo_pairs ) {
        $self->log->logdie('No suitable gap oligo pairs found');
        return;
    }

    my $oligo_pair_file =  $self->validated_oligo_dir->file('gap_oligo_pairs.yaml');
    DumpFile( $oligo_pair_file, $self->oligo_pairs );

    return;
}

1;

__END__
