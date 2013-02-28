package Test::ObjectRole::DesignCreate::OligoRegionsInsDel;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::OligoRegionsInsDel';

__PACKAGE__->meta->make_immutable;

1;

__END__
