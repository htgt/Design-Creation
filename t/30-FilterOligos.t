#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/lib";
use Log::Log4perl qw( :levels );
use Test::DesignCreate::CmdRole::FilterOligos;

Log::Log4perl->easy_init( $WARN );

Test::Class->runtests;
