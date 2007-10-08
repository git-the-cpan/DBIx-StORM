#!/usr/bin/perl

use strict;
use warnings;

use Test;
my $tests;
BEGIN { $tests = 2; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

use FindBin;
use lib $FindBin::Bin;
do "table_setup_generic.pl" or die $!;
die $@ if $@;

package Fruit;

use base "DBIx::StORM::Class";

__PACKAGE__->config(
	connection => sub { no warnings; return $::storm; },
	table      => "fruit"
);

package Variety;

use base qw(Fruit);

__PACKAGE__->config(
	table => "variety"
);

package main;

my $variety = Variety->grep(sub { $_->{fruit} == 3 })->lookup;

ok(defined($variety) and $variety->isa("Variety"));

my $apple = $variety->{fruit};

ok(defined($apple) and $apple->isa("Fruit"));

main::pulldown();
