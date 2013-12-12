#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl ':easy';
use Pod::Usage;
use Perl6::Slurp;
use Text::CSV;
use Path::Class;
use YAML::Any qw( LoadFile );

use Smart::Comments;

my $log_level = $WARN;
GetOptions(
    'help'          => sub { pod2usage( -verbose => 1 ) },
    'man'           => sub { pod2usage( -verbose => 2 ) },
    'debug'         => sub { $log_level = $DEBUG },
    'verbose'       => sub { $log_level = $INFO },
    'file=s'        => \my $log_file,
    'dir=s'         => \my $dir,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );

LOGDIE( "Must specify --log-file" ) unless $log_file;
LOGDIE( "Must specify --base-dir" ) unless $dir;

my $base_dir = dir( $dir )->absolute;

# Parse the fail file to work out why it failed
# If I can modify the parameters for design
# Output redone design parameters into new csv file

{
    my $failed_designs = grab_failed_designs( $log_file );

    for my $exon ( keys %{ $failed_designs } ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $exon );
        DEBUG( 'Working on new exon' );
        new_design_parameters( $exon, $failed_designs->{ $exon } );

        last;
    }
}

=head2 grab_failed_designs

Parse the log file of the design create run to find designs that failed

=cut
sub grab_failed_designs {
    my ( $log_file  ) = @_;
    my %failed_designs;

    my @input = slurp $log_file;
    chomp( @input );

    for my $line ( @input ) {
        if ( $line =~ /ERROR\s(\S*)\s(\S*)\sDESIGN\sINCOMPLETE:\s(.*)$/  ) {
            my $gene = $1;
            my $exon = $2;
            my $error_reason = $3;
            $failed_designs{$exon} = $gene;
        }
    }

    return \%failed_designs;
}

=head2 new_design_parameters

Generate new design parameters for failed design

=cut
sub new_design_parameters {
    my ( $exon, $gene ) = @_;

    my ( $params, $fail ) = grab_params_and_fail_data( $exon, $gene );

    return;
}

=head2 grab_params_and_fail_data

Grab the working directory of the failed design.
Then find the fail.yaml and design_parameters.yaml file.
Load these yaml files into hashes and return these.

=cut
sub grab_params_and_fail_data {
    my ( $exon, $gene ) = @_;

    my $work_dir_name = $gene . '#' . $exon;
    $work_dir_name =~ s/://g;
    my $work_dir = $base_dir->subdir( $work_dir_name );
    unless ( $base_dir->contains( $work_dir ) ) {
        ERROR( "Can not find work dir $work_dir_name" );
    }

    my $params_file = $work_dir->file( 'design_parameters.yaml' );
    my $fail_file = $work_dir->file( 'fail.yaml' );

    my $params = LoadFile( $params_file );
    my $fail = LoadFile( $fail_file );

    return ( $params, $fail );
}

#            mask_by_lower_case => 'yes',
#            region_length_3F => 100,
#            region_length_3R => 500,
#            region_length_5F => 500,
#            region_length_5R => 100,
#            region_length_5R_EF => 200,
#            region_length_EF => 100,
#            region_length_ER => 100,
#            region_length_ER_3F => 200,
#            region_offset_3R => 1000,
#            region_offset_5F => 1000,
#            region_offset_5R_EF => 200,
#            region_offset_ER_3F => 100,
#            repeat_mask_class => [ 'trf', 'dust' ],

__END__

=head1 NAME

failed_design_redo.pl -

=head1 SYNOPSIS

  failed_design_redo.pl log-files [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output

=head1 DESCRIPTION

=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
