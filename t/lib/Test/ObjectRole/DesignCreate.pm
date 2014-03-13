package Test::ObjectRole::DesignCreate;

use Moose;
use Fcntl; # O_ constants
use namespace::autoclean;

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
DesignCreate::Role::Common
DesignCreate::Role::EnsEMBL
);

=head2 update_design_attempt_record

For step commands we do not update design attempt data

=cut
sub update_design_attempt_record {
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
