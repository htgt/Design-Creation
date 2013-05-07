package Test::DesignCreate::Role::OligoRegionCoordinates;

use strict;
use warnings FATAL => 'all';

use Test::Most;
use Path::Class qw( tempdir dir );
use Bio::SeqIO;
use base qw( Test::DesignCreate::Class Class::Data::Inheritable );

# Testing
# DesignCreate::Role::OligoRegionCoordinates

BEGIN {
    __PACKAGE__->mk_classdata( 'test_role' => 'DesignCreate::Role::OligoRegionCoordinates' );
}

sub get_oligo_region_offset : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $offset = $o->get_oligo_region_offset('G5'), 'can get_oligo_region_offset';
    is $offset, $o->G5_region_offset, 'is expected offset value';
    throws_ok { $o->get_oligo_region_offset('M3') }
        qr/Attribute M3_region_offset does not exist/, 'throws error on unexpected oligo name';

}

sub get_oligo_region_length : Tests(4) {
    my $test = shift;
    ok my $o = $test->_get_test_object, 'can grab test object';

    ok my $length = $o->get_oligo_region_length('G5'), 'can get_oligo_region_length';
    is $length, $o->G5_region_length, 'have correct oligo region length value';

    throws_ok {
        $o->get_oligo_region_length('M3')
    } qr/Attribute M3_region_length does not exist/
        , 'throws error on unexpected oligo name';

}

sub _get_test_object {
    my ( $test, $strand ) = @_;
    $strand //= 1;

    my $metaclass = $test->get_test_object_metaclass();
    return $metaclass->new_object(
        dir           => tempdir( TMPDIR => 1, CLEANUP => 1 )->absolute,
        chr_name      => 11,
        chr_strand    => $strand,
        design_method => 'deletion',
        target_genes  => [ 'test_gene' ],
    );
}

1;

__END__
