package Test::ObjectRole::DesignCreate::PickGapOligos;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::PickGapOligos';

__PACKAGE__->meta->make_immutable;

1;

__END__
