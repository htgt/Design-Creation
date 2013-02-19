#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/lib";
use Log::Log4perl qw( :levels );
use Test::DesignCreate::CmdRole::OligoTargetRegions;

Log::Log4perl->easy_init( $DEBUG );

Test::Class->runtests;
