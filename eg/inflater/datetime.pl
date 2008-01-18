#!/usr/bin/perl

use strict;
use warnings;

use DBIx::StORM;
use DBIx::StORM::Inflater::DateTime;
use DateTime;

$DBIx::StORM::DEBUG = 0;

my $storm = DBIx::StORM->connect("dbi:mysql:database=test", "root", "");

$storm->dbi->do("DROP TABLE IF EXISTS datetest");

$storm->dbi->do("CREATE TABLE datetest (id INT PRIMARY KEY, dt DATE, ts TIMESTAMP)");

$storm->inflater(DBIx::StORM::Inflater::DateTime->new);

my $table = $storm->{datetest};

my $dt = DateTime->now;

$table->insert(sub {
	$_->{id} = 1;
	$_->{dt} = $dt;
	$_->{ts} = $dt;
});

my $record = $table->grep(sub { $_->{id} == 1 })->lookup;

printf("DT is an object of type \%s\n", ref $record->{dt});
printf("DT is an object of type \%s\n", ref $record->{ts});

$storm->dbi->do("DROP TABLE IF EXISTS datetest");
