
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Create Knock-Out Designs",
  "AUTHOR" => "Wellcome Trust Sanger Institute",
  "BUILD_REQUIRES" => {
    "App::Cmd::Tester" => 0,
    "Class::Data::Inheritable" => 0,
    "English" => 0,
    "File::Copy::Recursive" => 0,
    "File::Find" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "LIMS2::Util::EnsEMBL" => 0,
    "MooseX::Getopt" => 0,
    "Smart::Comments" => 0,
    "Storable" => 0,
    "Test::Class" => 0,
    "Test::MockObject" => 0,
    "Test::More" => "0.88",
    "Test::Most" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Design-Creation",
  "EXE_FILES" => [
    "bin/create-multiple-designs.pl",
    "bin/design-create",
    "bin/design-create-step",
    "bin/farm-wrapper-script.sh"
  ],
  "LICENSE" => "perl",
  "NAME" => "Design::Creation",
  "PREREQ_PM" => {
    "Bio::EnsEMBL::Registry" => 0,
    "Bio::Perl" => 0,
    "Bio::Seq" => 0,
    "Bio::SeqIO" => 0,
    "Bio::Tools::Primer3Redux" => 0,
    "Bio::Tools::Run::Primer3Redux" => 0,
    "Const::Fast" => 0,
    "Data::Dump" => 0,
    "Data::Printer" => 0,
    "DateTime" => 0,
    "Exporter" => 0,
    "Fcntl" => 0,
    "Getopt::Long" => 0,
    "IPC::Run" => 0,
    "IPC::System::Simple" => 0,
    "JSON" => 0,
    "LIMS2::REST::Client" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => 0,
    "Log::Log4perl" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "MooseX::App::Cmd" => 0,
    "MooseX::App::Cmd::Command" => 0,
    "MooseX::ClassAttribute" => 0,
    "MooseX::Log::Log4perl" => 0,
    "MooseX::SimpleConfig" => 0,
    "MooseX::Types" => 0,
    "MooseX::Types::Moose" => 0,
    "MooseX::Types::Path::Class::MoreCoercions" => 0,
    "Path::Class" => 0,
    "Pod::Usage" => 0,
    "Scalar::Util" => 0,
    "Text::CSV" => 0,
    "Throwable::Error" => 0,
    "Try::Tiny" => 0,
    "WebAppCommon::Util::EnsEMBL" => 0,
    "YAML::Any" => 0,
    "YAML::Tiny" => 0,
    "base" => 0,
    "feature" => 0,
    "namespace::autoclean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.038",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



