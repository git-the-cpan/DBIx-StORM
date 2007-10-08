#!/usr/bin/perl

use strict;
use warnings;

use Test;
my $tests;
BEGIN { $tests = 1; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

use FindBin;
use lib $FindBin::Bin;
do "table_setup_generic.pl" or die $!;
die $@ if $@;

our $storm;

my $apple = $storm->{fruit}->grep(sub { $_->{id} == 1 })->lookup;

ok(not defined($apple->{notthere}));

main::pulldown();
