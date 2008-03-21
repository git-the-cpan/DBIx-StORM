#!/usr/bin/perl

use strict;
use warnings;

use DBIx::StORM;
use DBIx::StORM::Inflater::Storable;

use Data::Dumper;

$DBIx::StORM::DEBUG = 0;

my $storm = DBIx::StORM->connect("dbi:DBM:");

$storm->dbi->do("DROP TABLE IF EXISTS storabletest");
$storm->dbi->do("CREATE TABLE storabletest (dKey INT, dVal VARCHAR(255))");

my $inflater = DBIx::StORM::Inflater::Storable->new;
$inflater->freeze("storabletest->dVal");

$storm->inflater($inflater);

my $value = { hashkey => [ "array1", "array2" ] };

print "Before storing in database:\n", Dumper($value), "\n";

my $table = $storm->{storabletest};
$table->insert(sub {
	$_->{dKey} = 1;
	$_->{dVal} = $value;
});

$storm->dbi->disconnect;

# Reconnect
$storm = DBIx::StORM->connect("dbi:DBM:");
$storm->inflater($inflater);

$value = $storm->{storabletest}->lookup("dVal");

print "After storing in database:\n", Dumper($value), "\n";

$storm->dbi->do("DROP TABLE IF EXISTS storabletest");
