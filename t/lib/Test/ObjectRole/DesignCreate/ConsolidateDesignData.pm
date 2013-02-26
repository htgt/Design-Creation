package Test::ObjectRole::DesignCreate::ConsolidateDesignData;

use Moose;
use namespace::autoclean;

extends 'Test::ObjectRole::DesignCreate';
with 'DesignCreate::CmdRole::ConsolidateDesignData';

__PACKAGE__->meta->make_immutable;

1;

__END__
