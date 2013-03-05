package Test::ObjectRole::DesignCreate::PickBlockOligos;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::PickBlockOligos';

__PACKAGE__->meta->make_immutable;

1;

__END__
