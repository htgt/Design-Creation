package DesignCreate::Cmd::Complete;

=head1 NAME

DesignCreate::Cmd::Complete

=head1 DESCRIPTION

Base class for all complete design create commands,
These are commands that merge together multiple steps to create a design

=cut

use Moose;
use Const::Fast;
use namespace::autoclean;

extends qw( DesignCreate::Cmd );
with qw(
DesignCreate::Role::CmdComplete
);

has persist => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => [ 'Getopt' ],
    documentation => 'Persist design to LIMS2',
    default       => 0
);

# Turn off the following attributes command line option attribute
# these values should note be set when running the design creation
# process end to end
const my @ATTRIBUTES_NO_CMD_OPTION => qw(
target_file
exonerate_target_file
aos_location
base_chromosome_dir
genomic_search_method
);

my $meta = __PACKAGE__->meta;
for my $attribute ( @ATTRIBUTES_NO_CMD_OPTION ) {
    if ( $meta->has_attribute($attribute) ) {
        has '+' . $attribute => ( traits => [ 'NoGetopt' ] );
    }
}

#TODO will around execute work here? sp12 Tue 11 Mar 2014 11:44:41 GMT
# augment / inner would work but not sure it playes with MooseX::App::Cmd

__PACKAGE__->meta->make_immutable;

1;

__END__
