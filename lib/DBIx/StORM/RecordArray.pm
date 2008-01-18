#!/usr/bin/perl

package DBIx::StORM::RecordArray;

use strict;
use warnings;

use Carp;

use DBIx::StORM::Record;

sub TIEARRAY {
	my $class = shift;
	my $params = shift;
	my $self = {
		%$params,
		pointer => -1,
		last_result => undef
	};

	return bless $self => $class;
}

sub EXTEND { }

=begin NaturalDocs

Method: FETCH (private instance)

  Fetch a DBIx::StORM::Record object for the next result in the RecordSet.

Parameters:

  String $index - The column name to fetch

Returns:

  Object - of type DBIx::StORM::Record

=end NaturalDocs

=cut

sub FETCH {
	my $self = shift;
	my $index = shift;

	DBIx::StORM->_debug(3, "accessing index $index\n");

	# DBI doesn't really do random access (some databases don't appreciate
	# it), so the veneer is only supposed to permit simple in-order
	# iteration. It turns out you need hold on to the previous result
	# if you want foreach to work.
	if ($self->{pointer} != $index and $self->{pointer} + 1 != $index) {
		die("Out of order RecordArray access not permitted");
	}

	# If foreach wants the previous result, we can skip a whole load
	# of effort as we cached it.
	if ($self->{pointer} == $index) { return $self->{last_result}; }

	# Increment our expectation of the next index we're expecting
	$self->{pointer}++;

	# Get the data for the row and clone it so it can be modified.
	my $row = [ $self->{sth}->fetchrow_array ];

	# We should have got a row - otherwise we've run off the end of the
	# "array"
	if (not $row) { return undef; }

	# We may need to build a table mapping if this is the first result in
	# the RecordSet
	if (not $self->{table_mapping}) {
		$self->{table_mapping} = $self->{table}->_storm->_sqldriver->build_table_mapping($self->{table}, $self->{sth});
	}

	# If the connection has an inflation callback, call it now
	if (my @i = $self->{table}->_storm->_inflaters) {
		foreach(@i) {
			$row = $_->inflate($self->{table}->_storm, $row, $self->{sth},
				$self->{table_mapping});
		}
	}

	# And actually make the result
	return $self->{last_result} = DBIx::StORM::Record->_new({
		table          => $self->{table},
		content        => $row,
		base_reference => $self->{table}->name(),
		resultset      => $self->{resultset},
		table_mapping  => $self->{table_mapping}
	});
}

sub FETCHSIZE {
	return shift()->{sth}->rows;
}

foreach my $method (qw(STORE STORESIZE POP PUSH SHIFT UNSHIFT SPLICE DELETE EXISTS)) {
	no strict "refs";
	*$method = sub { croak("cannot $method a result set"); }
}

1;
