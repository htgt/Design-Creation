#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Pod::Usage;
use LIMS2::REST::Client;
use YAML::Any qw( LoadFile DumpFile );
use Moose;
use Text::CSV;
use Data::Dumper;
use Log::Log4perl qw( :easy );
use Smart::Comments;


my ( $file, $dir );
GetOptions(
    'help'            => sub { pod2usage( -verbose => 1 ) },
    'man'             => sub { pod2usage( -verbose => 2 ) },
    'file=s'          => \$file,
    'debug'           => \my $debug,
) or pod2usage(2);

die( 'Specify file with design info' ) unless $file;

has lims2_api => (
    is         => 'ro',
    isa        => 'LIMS2::REST::Client',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1
);

sub _build_lims2_api {
    my $self = shift;

    return LIMS2::REST::Client->new_with_config();
}

my $this_user = $ENV{'USER'} . '@sanger.ac.uk';


my $rest = _build_lims2_api();

my $lims = {
    lims2_api         => _build_lims2_api(),
    dir               => $dir,
    design_method     => 'conditional-inversion',
};

my $self = $lims->{lims2_api}->_build_ua();


my @well_names = ("A01","A02","A03","A04","A05","A06","A07","A08","A09","A10","A11","A12","B01","B02","B03","B04","B05","B06","B07","B08","B09","B10","B11","B12","C01","C02","C03","C04","C05","C06","C07","C08","C09","C10","C11","C12","D01","D02","D03","D04","D05","D06","D07","D08","D09","D10","D11","D12","E01","E02","E03","E04","E05","E06","E07","E08","E09","E10","E11","E12","F01","F02","F03","F04","F05","F06","F07","F08","F09","F10","F11","F12","G01","G02","G03","G04","G05","G06","G07","G08","G09","G10","G11","G12","H01","H02","H03","H04","H05","H06","H07","H08","H09","H10","H11","H12");
my @well_design_ids;


my $input_csv = Text::CSV->new();
open ( my $input_fh, '<', $file ) or die( "Can not open $file " . $! );
$input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );

while ( my $data = $input_csv->getline_hr( $input_fh ) ) {

    my $species = $data->{species};

    my $gene_type = calculate_gene_type($data->{gene_id});

    my $gene_ids = [ { gene_id => $data->{gene_id}, gene_type_id => $gene_type } ];

    my $chr_strand = $data->{chr_strand};

    my ($LAL_start, $LAL_end, $LAR_start, $LAR_end, $RAL_start, $RAL_end, $RAR_start, $RAR_end);

    ($LAL_start, $LAL_end) = ($1, $2) if ($data->{LAL_loc} =~ /:(\d*)-(\d*)/);
    my $LAL_seq = $data->{LAL_seq};
    ## $LAL_start
    ## $LAL_end
    ## $LAL_seq

    ($LAR_start, $LAR_end) = ($1, $2) if ($data->{LAR_loc} =~ /:(\d*)-(\d*)/);
    my $LAR_seq = $data->{LAR_seq};
    ## $LAR_start
    ## $LAR_end
    ## $LAR_seq

    ($RAL_start, $RAL_end) = ($1, $2) if ($data->{RAL_loc} =~ /:(\d*)-(\d*)/);
    my $RAL_seq = $data->{RAL_seq};
    ## $RAL_start
    ## $RAL_end
    ## $RAL_seq

    ($RAR_start, $RAR_end) = ($1, $2) if ($data->{RAR_loc} =~ /:(\d*)-(\d*)/);
    my $RAR_seq = $data->{RAR_seq};
    ## $RAR_start
    ## $RAR_end
    ## $RAR_seq

    my $oligos;

    if ( ($chr_strand eq '1' && $LAL_start < $RAR_start) || ($chr_strand eq '-1' && $LAL_start > $RAR_start) ) {

        $oligos = [
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $LAL_end,
                            chr_name => $data->{chr_name},
                            chr_start => $LAL_start,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $LAL_seq,
                type => '5F'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $LAR_end,
                            chr_name => $data->{chr_name},
                            chr_start => $LAR_start,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $LAR_seq,
                type => '5R'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $RAL_end,
                            chr_name => $data->{chr_name},
                            chr_start => $RAL_start,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $RAL_seq,
                type => '3F'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $RAR_end,
                            chr_name => $data->{chr_name},
                            chr_start => $RAR_start,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $RAR_seq,
                type => '3R'
              }
        ];

    } elsif ( ($chr_strand eq '1' && $LAL_start > $RAR_start) || ($chr_strand eq '-1' && $LAL_start < $RAR_start) ) {

        $oligos = [
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $RAR_start,
                            chr_name => $data->{chr_name},
                            chr_start => $RAR_end,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $RAR_seq,
                type => '5F'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $RAL_start,
                            chr_name => $data->{chr_name},
                            chr_start => $RAL_end,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $RAL_seq,
                type => '5R'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $LAR_start,
                            chr_name => $data->{chr_name},
                            chr_start => $LAR_end,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $LAR_seq,
                type => '3F'
              },
              {
                loci => [
                          {
                            assembly => $data->{assembly},
                            chr_end => $LAL_start,
                            chr_name => $data->{chr_name},
                            chr_start => $LAL_end,
                            chr_strand => $chr_strand,
                          }
                        ],
                seq => $LAL_seq,
                type => '3R'
              }
        ];


    } else {

        die "ERROR building oligos";

    }

    ## $oligos

    my $design_data = {
            created_by => $this_user,
            gene_ids => $gene_ids,
            oligos => $oligos,
            species => $species,
            type => 'conditional-inversion',
        };
    ## $design_data

    my $design = $lims->{lims2_api}->POST('design', $design_data );
    ## $design

    my $design_id = $design->{id};
    ## $design_id

    print "DESIGN ID: $design_id imported\n";

    push @well_design_ids, $design_id;

}

open DESIGN_CSV, ">", 'design_upload.csv' or die $!;

print DESIGN_CSV "well_name,design_id\n";


foreach my $design_id ( @well_design_ids ) {
    my $well_name = shift @well_names;
    print DESIGN_CSV "${well_name},${design_id}\n";
}



print scalar @well_design_ids . " wells created for DESIGN plate csv upload file design_upload.csv\n";



=head2 calculate_gene_type

Work out type of gene identifier.

=cut
sub calculate_gene_type {
    my ( $gene_id ) = @_;

    my $gene_type = $gene_id =~ /^MGI/  ? 'MGI'
                  : $gene_id =~ /^HGNC/ ? 'HGNC'
                  : $gene_id =~ /^LBL/  ? 'enhancer-region'
                  : $gene_id =~ /^CGI/  ? 'CPG-island'
                  : $gene_id =~ /^mmu/  ? 'miRBase'
                  :                       'marker-symbol'
                  ;

    return $gene_type;
}




__END__

=head1 NAME

upload_conditional_inversion_designs.pl - Uploads designs based on a file of pre-selected crispr conditional design data

=head1 SYNOPSIS

  upload_conditional_inversion_designs.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Print debug messages
      --file            File with design data.

=head1 DESCRIPTION

Takes design information for multiple designs from file and tries to create these designs.

The input file will be a csv file, each row represents a design, each column a parameter given
by the crispr conditional design selection process.
The output will be design_upload.csv file, that is a DESIGN upload file and can be used to create the DESIG plate of the provided designs.

=cut
