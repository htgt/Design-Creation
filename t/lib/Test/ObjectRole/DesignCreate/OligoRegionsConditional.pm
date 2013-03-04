package Test::ObjectRole::DesignCreate::OligoRegionsConditional;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::OligoRegionsConditional';

__PACKAGE__->meta->make_immutable;

1;

__END__
