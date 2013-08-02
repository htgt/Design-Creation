package DesignCreate::Role::FilterOligos;

=head1 NAME

DesignCreate::Role::FilterOligos

=head1 DESCRIPTION


=cut

use Moose::Role;
use DesignCreate::Util::Exonerate;
use DesignCreate::Exception;
use YAML::Any qw( LoadFile DumpFile );
use DesignCreate::Types qw( PositiveInt );
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use Const::Fast;
use Fcntl; # O_ constants
use Bio::SeqIO;
use Try::Tiny;
use List::MoreUtils qw( any );
use namespace::autoclean;

#requires '_validate_oligo';

has all_oligos => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_all_oligos {
    my $self = shift;
    my %all_oligos;

    for my $oligo_type ( $self->expected_oligos ) {
        my $oligo_file = $self->get_file( "$oligo_type.yaml", $self->oligo_finder_output_dir );

        my $oligos = LoadFile( $oligo_file );
        DesignCreate::Exception->throw( "No oligo data in $oligo_file for $oligo_type oligo" )
            unless $oligos;

        $all_oligos{$oligo_type} = $oligos;
    }

    return \%all_oligos;
}

has invalid_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt', 'Hash' ],
    default => sub { {  } },
    handles => {
        add_invalid_oligo   => 'set',
        oligo_is_invalid    => 'exists',
        have_invalid_oligos => 'count',
    }
);

has validated_oligos => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {  } },
);

=head2 validate_oligos

Loop through all the candidate oligos for the oligo types we expect for 
given the design we have.

Run checks against the oligos, if they pass place them in a validated oligo hash.
Throw error if we have no valid oligoes for a oligo type.

=cut
sub validate_oligos {
    my $self = shift;

    for my $oligo_type ( $self->expected_oligos ) {
        $self->log->debug( "Validating $oligo_type oligos" );

        for my $oligo_data ( @{ $self->all_oligos->{$oligo_type} } ) {
            if ( $self->validate_oligo( $oligo_data, $oligo_type ) ) {
                push @{ $self->validated_oligos->{$oligo_type} }, $oligo_data;
            }
            else {
                $self->add_invalid_oligo( $oligo_data->{id} => 1 );
            }
        }

        unless ( exists $self->validated_oligos->{$oligo_type} ) {
            DesignCreate::Exception->throw("No valid $oligo_type oligos, halting filter process");
        }

        $self->log->info("We have $oligo_type oligos that pass checks");
    }

    return 1;
}

=head2 validate_oligo

Run checks against individual oligo to make sure it is valid.
If it passes all checks return 1, otherwise return undef.

Calls _validate_oligo which is defined in the CmdRole module that
consumes with role.

=cut
sub validate_oligo {
    my ( $self, $oligo_data, $oligo_type ) = @_;
    $self->log->debug( "$oligo_type oligo, id: " . $oligo_data->{id} );

    if ( !defined $oligo_data->{oligo} || $oligo_data->{oligo} ne $oligo_type )   {
        $self->log->error("Oligo name mismatch, expecting $oligo_type, got: "
            . $oligo_data->{oligo} . 'for: ' . $oligo_data->{id} );
        return;
    }

    my $oligo_slice = $self->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $self->design_param( 'chr_name' ),
    );

    $self->_validate_oligo( $oligo_data, $oligo_type, $oligo_slice );
}

=head2 output_validated_oligos

Loop through all the oligo types and dump the valid oligos we have
into a yaml file in the validated oligo directory.

=cut
sub output_validated_oligos {
    my $self = shift;

    for my $oligo_type ( keys %{ $self->validated_oligos } ) {
        my $filename = $self->validated_oligo_dir->stringify . '/' . $oligo_type . '.yaml';
        DumpFile( $filename, $self->validated_oligos->{$oligo_type} );
    }

    return;
}

1;

__END__
