package Test::ObjectRole::DesignCreate::TargetSequence;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::Role::TargetSequence';

__PACKAGE__->meta->make_immutable;

1;

__END__
