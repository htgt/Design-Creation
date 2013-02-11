package DesignCreate::Util::Exonerate;

use strict;
use warnings FATAL => 'all';

use Moose;
use DesignCreate::Types qw( PositiveInt YesNo );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use IPC::Run 'run';
use Const::Fast;
use namespace::autoclean;

with qw( MooseX::Log::Log4perl );

const my $RYO => "RESULT: %qi %qal %ql %pi %s %em %tab %tae\n";
const my $EXONERATE_CMD => '/software/team87/brave_new_world/app/exonerate-2.2.0-x86_64/bin/exonerate';

#
#Align sequence(s) against a genome to find number of hits
#pass a input file (sequences in fasta file) into exonerate
#

has query_file => (
    is       => 'ro',
    isa      => AbsFile,
    coerce   => 1,
    required => 1,
);

has target_file => (
    is       => 'ro',
    isa      => AbsFile,
    coerce   => 1,
    required => 1,
);

has ryo => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => $RYO,
);

has bestn => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
    default  => 20,
);

has score => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
    default  => 65,
);

has [
    qw(
        showalignment
        showsugar
        showvulgar
        )
    ] => (
    is       => 'ro',
    isa      => YesNo,
    required => 1,
    default  => 'no',
);

has percentage_hit_match => (
    is       => 'ro',
    isa      => PositiveInt,
    required => 1,
    default  => 80,
);

has alignment_model => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'affine:local',
);

has exonerate_output =>  (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_exonerate_output',
);

has matches => (
    is  => 'rw',
    isa => 'HashRef',
);

#
#Run exonerate against input fasta file, return output as string
#
sub run_exonerate {
    my $self = shift;

    my @command = (
        $EXONERATE_CMD,
        "--model",         $self->alignment_model,
        "--bestn",         $self->bestn,
        "--query",         $self->query_file->stringify,
        "--target",        $self->target_file->stringify,
        "--showalignment", $self->showalignment,
        "--showsugar",     $self->showsugar,
        "--showvulgar",    $self->showvulgar,
        "--score",         $self->score,
    );

    push @command, ( "--ryo", $self->ryo )
        if $self->ryo;
    $self->log->debug( "Exonerate Command: " . join( ' ', @command ) );

    my ( $out, $err ) = ( "", "" );
    run( \@command, '<', \undef, '>', \$out, '2>', \$err )
        or $self->log->logdie(
            "Failed to run exonerate: $err" );

    $self->exonerate_output( $out );

    return $self->exonerate_output;
}

#
#Parse exonerate output and return number of valid hits per sequence
#
sub parse_exonerate_output {
    my $self = shift;
    my %matches;

    unless ( $self->has_exonerate_output ) {
        $self->log->error('No exonerate output to parse');
        return;
    }

    if ( $self->ryo ne $RYO ) {
        $self->log->error( 'Cannot return matches if RYO attribute is modified from default' );
        return;
    }

    foreach my $line ( map{ chomp; $_ } split(/\n/, $self->exonerate_output) ) {
        if ( $line =~ /^RESULT/ ) {
            my @exonerate_output = split /\s/, $line;

            my $seq_id               = $exonerate_output[1];
            my $alignment_length     = $exonerate_output[2];
            my $seq_length           = $exonerate_output[3];
            my $percentage_alignment = $exonerate_output[4];
            my $alignment_score      = $exonerate_output[5];
            my $mismatch_bases       = $exonerate_output[6];
            my $start                = $exonerate_output[7];
            my $end                  = $exonerate_output[8];

            if ($mismatch_bases) {
                $self->log->debug("$seq_id alignment has $mismatch_bases mismatch(s) - skip");
                next;
            }
            my $percentage_match = $percentage_alignment * ( $alignment_length / $seq_length );

            if ($percentage_match == 100) {
                $matches{$seq_id}{'exact_matches'}++;
                $matches{$seq_id}{'start'} = $start;
                $matches{$seq_id}{'end'}   = $end;
            }

            $matches{$seq_id}{'hits'}++ if $percentage_match >= $self->percentage_hit_match;
            $self->log->debug("$seq_id - Percent Match: $percentage_match");
        }
    }

    $self->matches( \%matches );

    return $self->matches;
}

__PACKAGE__->meta->make_immutable;

1;

__END__