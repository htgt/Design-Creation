package Test::ObjectRole::DesignCreate;

use Moose;
use Fcntl; # O_ constants
use namespace::autoclean;

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
DesignCreate::Role::CmdStep
DesignCreate::Role::EnsEMBL
);

__PACKAGE__->meta->make_immutable;

1;

__END__
