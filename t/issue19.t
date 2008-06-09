#!/usr/bin/perl

use strict;
#use warnings;

# These tests only apply to perl >= 5.8.0 as it needs
# B::object_2svref

# Also test 3 often passed but sometimes doesn't. Why this is
# the case is ongoing, hence the onfail debugging information.

use Test;
my $tests;
our $storm;
BEGIN { $tests = 3; plan tests => $tests, todo => [3], onfail => sub { eval {
	my $r = B::svref_2object($storm->{fruit}->grep(sub { $_->{id} == 1 })->lookup);
	print STDERR "Records look like a " . ref($r) . "\n";
	print STDERR "Records " . ($r->can("RV") ? "can" : "can't") . " be treated as an RV\n";
	print STDERR "Records " . (($r->can("RV") and $r->RV->can("RV")) ? "can" : "can't") . " be treated as an RV of an RV\n";
	require B::Concise;
	require Data::Dumper; import Data::Dumper;
	my $hr = {};
	B::Concise::concise_sv($r, $hr);
	print STDERR "B::Concise thinks Records look like " . Dumper($hr);
} } };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

use FindBin;
use lib $FindBin::Bin;
do "table_setup_generic.pl" or die $!;
die $@ if $@;

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

#main::pulldown();
