#!/usr/bin/perl

package DBIx::StORM::SQLDriver::mysql;

use strict;
use warnings;

use base "DBIx::StORM::SQLDriver";

use DBIx::StORM;

sub _last_insert_id {
	my ($self, $table) = @_;

	# We need one PK if we're to stand a chance!
	my $pks = $self->primary_key($table);
	return undef unless (@$pks == 1);

	# Attempt to query the insert ID
	my $dbh = $table->_storm->dbi;
	my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
	$sth->execute() or die($dbh->errstr());
	my $val = $sth->fetchrow_arrayref()->[0];

	# Did we get a response?
	return undef unless $val;

	# Make something sensible out of it
	my $field = $pks->[0];
	$field =~ s/.*->//;
	return { $pks->[0] => $val };
}

sub _fetch_primary_key {
	my $self = shift;
	my $table = shift;

	my @toreturn;

	my $sth = $table->_storm->dbi->prepare("DESCRIBE " . $table->name());
	$sth->execute or die ("DBI->execute: $!");
	while(my $row = $sth->fetchrow_hashref()) {
		next unless ($row->{Key} eq "PRI");
		push @toreturn, $table->name . "->" . $row->{Field};
	}

	return @toreturn;
}

sub _fetch_foreign_keys {
	my $self = shift;
	my $table = shift;

	my %toreturn;

	my $sth = $table->_storm->dbi->prepare("SHOW CREATE TABLE " . $table->name());
	$sth->execute or die ("DBI->execute: $!");
	my $create = $sth->fetchrow_hashref()->{"Create Table"};

	while($create =~ m/CONSTRAINT `.*?` FOREIGN KEY \(`(.*?)`\) REFERENCES `(.*?)` \(`(.*?)`\)/g) {
		$toreturn{$1} = "$2->$3";
	}

	return %toreturn;
}

sub _final_fixup {
        my ($self, $params, $query) = @_;

	# Is it a select with limit?
	if (not $params->{verb} and $params->{limit}) {
		$query .= " LIMIT " . $params->{limit};
	}

        return $query;
}

sub _identifier_quote {
        '`'
}

sub _string_quote {
        "'"
}

1;
