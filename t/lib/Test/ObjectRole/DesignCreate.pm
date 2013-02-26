package Test::ObjectRole::DesignCreate;

use strict;
use warnings FATAL => 'all';

use Moose;
use DesignCreate::Types qw( DesignMethod );
use DesignCreate::Exception;
use DesignCreate::Exception::MissingFile;
use namespace::autoclean;

has design_method => (
    is       => 'ro',
    isa      => DesignMethod,
    default  => 'deletion',
);

has dir => (
    is  => 'ro',
    isa => 'Path::Class::Dir',
);

has design_data_file_name => (
   is      => 'ro',
   isa     => 'Str',
   default => 'design_data.yaml',
);

has validated_oligo_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'validated_oligos' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
}

has aos_output_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_aos_output_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'aos_output' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
}

has oligo_target_regions_dir => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub _build_oligo_target_regions_dir {
    my $self = shift;

    my $sub_dir = $self->dir->subdir( 'oligo_target_regions' )->absolute;
    $sub_dir->mkpath();

    return $sub_dir;
}

sub get_file {
    my ( $self, $filename, $dir ) = @_;

    my $file = $dir->file( $filename );
    DesignCreate::Exception::MissingFile->throw( file => $file, dir => $dir )
        unless $dir->contains( $file );

    return $file;
}

with qw(
MooseX::Log::Log4perl
MooseX::Getopt
);

__PACKAGE__->meta->make_immutable;

1;

__END__
