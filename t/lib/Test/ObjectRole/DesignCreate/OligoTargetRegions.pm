package Test::ObjectRole::DesignCreate::OligoTargetRegions;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::OligoTargetRegions';

__PACKAGE__->meta->make_immutable;

1;

__END__
