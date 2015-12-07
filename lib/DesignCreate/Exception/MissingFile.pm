package DesignCreate::Exception::MissingFile;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Exception::MissingFile::VERSION = '0.038';
}
## use critic


use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Exception );

has '+message' => (
    default => 'File not found'
);

has dir => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has file => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

override as_string => sub {
    my $self = shift;

    my $str = 'Cannot find file ' . $self->file->basename . ' in directory ' . $self->dir->stringify;

    if ( $self->show_stack_trace ) {
        $str .= "\n\n" . $self->stack_trace->as_string;
    }

    return $str;
};

around as_hash => sub {
    my $orig = shift;
    my $self = shift;

    my $hash = $self->$orig;

    $hash->{file} = $self->file->basename;
    $hash->{dir} = $self->dir->stringify;

    return $hash;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
