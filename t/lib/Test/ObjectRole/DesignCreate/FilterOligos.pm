package Test::ObjectRole::DesignCreate::FilterOligos;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::FilterOligos';

__PACKAGE__->meta->make_immutable;

1;

__END__
