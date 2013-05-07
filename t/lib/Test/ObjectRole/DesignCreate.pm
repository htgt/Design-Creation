package Test::ObjectRole::DesignCreate;

use Moose;
use Fcntl; # O_ constants
use namespace::autoclean;

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
DesignCreate::Role::Action
);

#
# The original methods delete and then recreate these directories.
# I already have some these directories set up with fixture data so I do
# not want that to happen in the tests.
#

around '_build_validated_oligo_dir' => sub {
    my $orig = shift;
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'validated_oligos' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
};

around '_build_aos_output_dir' => sub {
    my $orig = shift;
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'aos_output' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
};

around '_build_oligo_target_regions_dir' => sub {
    my $orig = shift;
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'oligo_target_regions' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
