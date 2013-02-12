package DesignCreate::Role::Oligos;

=head1 NAME

DesignCreate::Role::Oligos

=head1 DESCRIPTION

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt );
use Const::Fast;
use namespace::autoclean;

const my $DEFAULT_VALIDATED_OLIGO_DIR_NAME => 'validated_oligos';

has oligo_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Length of the oligos AOS is to find ( default 50 )',
    default       => 50,
    cmd_flag      => 'oligo-length',
);

has validated_oligo_dir => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    traits        => [ 'Getopt' ],
    documentation => 'Directory holding the validated oligos, '
                     . " defaults to [design_dir]/$DEFAULT_VALIDATED_OLIGO_DIR_NAME",
    coerce        => 1,
    cmd_flag      => 'validated-oligo-dir',
    lazy_build    => 1,
);

sub _build_validated_oligo_dir {
    my $self = shift;

    my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME )->absolute;
    $validated_oligo_dir->rmtree();
    $validated_oligo_dir->mkpath();

    return $validated_oligo_dir;
}

#sub _build_validated_oligo_dir {
    #my $self = shift;

    #my $validated_oligo_dir = $self->dir->subdir( $DEFAULT_VALIDATED_OLIGO_DIR_NAME );
    #unless ( $self->dir->contains( $validated_oligo_dir ) ) {
        #$self->log->logdie( "Can't find validated oligo file dir: "
                           #. $self->validated_oligo_dir->stringify );
    #}

    #return $validated_oligo_dir->absolute;
#}

1;

__END__
