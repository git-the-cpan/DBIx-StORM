#!/usr/bin/perl

use strict;
#use warnings;

# These tests only apply to perl >= 5.8.0
# as it needs B::object_2svref

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

my $apple  = $storm->{fruit}->grep(sub { $_->{id} == 1 })->lookup;
my $orange = $storm->{fruit}->grep(sub { $_->{id} == 2 })->lookup;
my $peach  = $storm->{fruit}->grep(sub { $_->{id} == 3 })->lookup;

my $mutant = $storm->{variety}->insert(sub {
	$_->{name}  = "SuperFlurby";
	$_->{fruit} = $apple;
});

my $skip_test = ($] < 5.008);

skip($skip_test, sub { defined($mutant) and $mutant->{fruit} and $mutant->{fruit}->{name} eq "apple" });

$mutant->{fruit} = $peach;

skip($skip_test, sub { defined($mutant) and $mutant->{fruit} and $mutant->{fruit}->{name} eq "peach" });

$storm->{variety}->grep(sub { $_->{fruit} == 3 })->update(sub {
	$_->{fruit} = $orange;
});

$mutant = $storm->{variety}->grep(sub {
	$_->{name} eq "SuperFlurby"
})->lookup;

skip($skip_test, sub { defined($mutant) and $mutant->{fruit} and $mutant->{fruit}->{name} eq "orange" });

main::pulldown();
