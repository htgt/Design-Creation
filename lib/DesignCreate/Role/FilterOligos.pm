package DesignCreate::Role::FilterOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::FilterOligos::VERSION = '0.022';
}
## use critic


=head1 NAME

DesignCreate::Role::FilterOligos

=head1 DESCRIPTION

Common attributes and subroutines used by the filter oligo commands.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::OligoValidation;
use YAML::Any qw( LoadFile DumpFile );
use Data::Printer;
use namespace::autoclean;

requires '_validate_oligo';

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
    my @no_valid_oligos_of_type;

    for my $oligo_type ( $self->expected_oligos ) {
        $self->log->debug( "Validating $oligo_type oligos" );

        for my $oligo_data ( @{ $self->all_oligos->{$oligo_type} } ) {
            # pass a string ref to $invalid_reason to the validate methods so we can get back the
            # reason oligo failed validation. We can not return this value directly from the
            # validation subroutines because they are set up to return true or false depending on
            # if the oligo passes the validation check or not.
            my $invalid_reason;
            if ( $self->validate_oligo( $oligo_data, $oligo_type, \$invalid_reason ) ) {
                push @{ $self->validated_oligos->{$oligo_type} }, $oligo_data;
            }
            else {
                $self->add_invalid_oligo( $oligo_data->{id} => $invalid_reason );
            }
        }

        if ( exists $self->validated_oligos->{$oligo_type} ) {
            $self->log->info("We have $oligo_type oligos that pass checks");
        }
        else {
            $self->log->warn( "No valid $oligo_type oligos" );
            push @no_valid_oligos_of_type, $oligo_type;
        }
    }

    if (@no_valid_oligos_of_type) {
        DesignCreate::Exception::OligoValidation->throw(
            oligo_types     => \@no_valid_oligos_of_type,
            invalid_reasons => $self->invalid_oligos,
        );
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
    my ( $self, $oligo_data, $oligo_type, $invalid_reason ) = @_;
    $self->log->debug( "$oligo_type oligo, id: " . $oligo_data->{id} );

    if ( !defined $oligo_data->{oligo} || $oligo_data->{oligo} ne $oligo_type )   {
        $self->log->error("Oligo name mismatch, expecting $oligo_type, got: "
            . $oligo_data->{oligo} . 'for: ' . $oligo_data->{id} );
        $$invalid_reason = "Type mismatch, expecting $oligo_type, got " . $oligo_data->{oligo};
        return;
    }

    my $oligo_slice = $self->get_slice(
        $oligo_data->{oligo_start},
        $oligo_data->{oligo_end},
        $self->design_param( 'chr_name' ),
    );

    return $self->_validate_oligo( $oligo_data, $oligo_type, $oligo_slice, $invalid_reason );
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

=head2 check_oligo_sequence

Check the oligo sequence we got from the oligo finder software matches up
to the sequence we grab from EnsEMBL using the oligo coordinates we have
worked out.

=cut
sub check_oligo_sequence {
    my ( $self, $oligo_data, $oligo_slice, $invalid_reason ) = @_;

    if ( $oligo_slice->seq ne uc( $oligo_data->{oligo_seq} ) ) {
        $self->log->error( 'Oligo seq does not match coordinate sequence: ' . $oligo_data->{id} );
        $self->log->trace( 'Oligo seq  : ' . $oligo_data->{oligo_seq} );
        $self->log->trace( "Ensembl seq: " . $oligo_slice->seq );
        $$invalid_reason = "Sequence does not match coordinate sequence";
        return 0;
    }

    $self->log->debug('Sequence for coordinates matches oligo sequence: ' . $oligo_data->{id} );
    return 1;
}

=head2 check_oligo_length

Check the length of the oligo sequence is the same value we expect.

=cut
sub check_oligo_length {
    my ( $self, $oligo_data, $invalid_reason) = @_;

    my $oligo_length = length($oligo_data->{oligo_seq});
    if ( $oligo_length != $oligo_data->{oligo_length} ) {
        $self->log->error("Oligo length is $oligo_length, should be "
                           . $oligo_data->{oligo_length} . ' for: ' . $oligo_data->{id} );
        $$invalid_reason = "Length is $oligo_length, should be " . $oligo_data->{oligo_length};
        return 0;
    }

    $self->log->debug('Oligo length correct for: ' . $oligo_data->{id} );
    return 1;
}

1;

__END__
