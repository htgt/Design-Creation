package Test::ObjectRole::DesignCreate::FindOligos;

use Moose;
use namespace::autoclean;
use Fcntl; # O_ constants

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::FindOligos';

__PACKAGE__->meta->make_immutable;

1;

__END__
