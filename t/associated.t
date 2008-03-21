#!/usr/bin/perl

use strict;
use warnings;

use Test;
my $tests;
BEGIN { $tests = 3; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

use FindBin;
use lib $FindBin::Bin;
do "table_setup_generic.pl" or die $!;
die $@ if $@;

our $storm;

my $fruit = $storm->{fruit}->identity(1);
ok($fruit and $fruit->{name} eq "apple");

my $varieties = $fruit->associated("variety");
foreach my $variety (@$varieties) {
	ok($variety and $variety->{fruit} and $variety->{fruit}->{name} eq "apple");
}

main::pulldown();
