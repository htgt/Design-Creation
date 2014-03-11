package DesignCreate::Types;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Types::VERSION = '0.022';
}
## use critic


use warnings FATAL => 'all';
use strict;

use Const::Fast;

use MooseX::Types -declare => [
    qw(
        Chromosome
        PositiveInt
        NaturalNumber
        YesNo
        Strand
        Oligo
        ArrayRefOfOligos
        Species
        DesignMethod
        AOSSearchMethod
    )
];

# import builtin types
use MooseX::Types::Moose qw/Int Str ArrayRef/;

const my %CHROMOSOMES => (
    map{ $_ => 1  } (1..22),
    X => 1,
    Y => 1,
    x => 1,
    y => 1,
);

#TODO add gibson oligos here? sp12 Fri 02 Aug 2013 15:00:50 BST
const my %OLIGOS => (
    map{ $_ => 1 } qw( G5 U5 U3 D5 D3 G3 ),
);

const my %SPECIES => (
    Mouse => 1,
    Human => 1,
);

const my %DESIGN_METHODS => (
    deletion          => 1,
    insertion         => 1,
    conditional       => 1,
    gibson            => 1,
    'gibson-deletion' => 1,
);

const my %AOS_SEARCH_METHODS => (
    blat  => 1,
    blast => 1,
);

subtype PositiveInt,
    as Int,
    where { $_ > 0 },
    message { "The number you provided, $_, was not a positive number" };

subtype NaturalNumber,
    as Int,
    where { $_ >= 0 },
    message { "The number you provided, $_, was not a natural number (positive or zero)" };

subtype YesNo,
    as Str,
    where { $_ =~ /^yes$/i || $_ =~ /^no$/i },
    message { "Invalid Yes or No value $_, must be yes or no" };

subtype Strand,
    as Int,
    where { $_ == 1  || $_ == -1 },
    message { "Invalid strand $_, must be 1 or -1" };

subtype Chromosome,
    as Str,
    where { exists $CHROMOSOMES{$_} },
    message { "Invalid chromosome name, $_, must be one off: ( " . join( ', ', sort keys %CHROMOSOMES ) . ' )' };

subtype Oligo,
    as Str,
    where { exists $OLIGOS{$_} },
    message { "Invalid oligo name $_, must be one off: ( " . join( ',', keys %OLIGOS ) . ' )'};

subtype ArrayRefOfOligos,
    as ArrayRef[Oligo];

subtype Species,
    as Str,
    where { exists $SPECIES{$_} },
    message { "Invalid species $_, must be one of: ( " . join( ', ', keys %SPECIES ) . ' )' };

subtype DesignMethod,
    as Str,
    where { exists $DESIGN_METHODS{$_} },
    message { "Invalid design method $_, must be one of: ( " . join( ', ', keys %DESIGN_METHODS ) . ' )' };

subtype AOSSearchMethod,
    as Str,
    where { exists $AOS_SEARCH_METHODS{$_} },
    message { "Invalid AOS search method $_, must be one of: ( " . join( ', ', keys %AOS_SEARCH_METHODS ) . ' )' };

1;
