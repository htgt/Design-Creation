#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/lib";
use Log::Log4perl qw( :levels );
use Test::DesignCreate::CmdRole::FetchOligoRegionsSequence;

Log::Log4perl->easy_init( $OFF );

Test::Class->runtests;
