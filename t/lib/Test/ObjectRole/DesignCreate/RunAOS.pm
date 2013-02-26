package Test::ObjectRole::DesignCreate::RunAOS;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::RunAOS';

__PACKAGE__->meta->make_immutable;

1;

__END__
