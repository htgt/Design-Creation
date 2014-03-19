package Test::ObjectRole::DesignCreate;

use Moose;
use Fcntl; # O_ constants
use Try::Tiny;
use namespace::autoclean;

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
DesignCreate::Role::Common
DesignCreate::Role::EnsEMBL
);

has persist => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0
);

=head2 update_design_attempt_record

When running standalone 'step' commands we would not update design attempt records. However when running it as part of a 'complete' design
create command we would attempt to update design attempt records.

We leave it up to the individual tests as to if the persist flag is
set to true or not.

=cut
sub update_design_attempt_record {
    my ( $self, $data ) = @_;
    return if !$self->persist;

    try{
        my $design_attempt = $self->lims2_api->PUT( 'design_attempt', $data );
    }
    catch {
        $self->log->error( "Error updating design attempt record: $_" );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
