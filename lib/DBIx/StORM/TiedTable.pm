#!/usr/bin/perl

package DBIx::StORM::TiedTable;

=begin NaturalDocs

Class: DBIx::StORM::TiedTable

An inner class used to represent a mapping of table names to
DBIx::StORM::Table objects for a given connection.

=end NaturalDocs

=cut

use strict;
use warnings;

=begin NaturalDocs

Method: TIEHASH (private static)

  Create a new tied object.

Parameters:

  Object $storm - The DBIx::StORM connection object

Returns:

  Object - A new DBIx::StORM::TiedTable object

=end NaturalDocs

=cut

sub TIEHASH {
	my ($class, $storm) = @_;
	my $self = { storm => $storm };
	return bless $self => $class;
}

=begin NaturalDocs

Method: FETCH (private instance)

  Fetch a table object for a particular table in the hash

Parameters:

  String $index - The name of the table to fetch a table object for

Returns:

  Object - Table object of type DBIx::StORM::Table

=end NaturalDocs

=cut

sub FETCH {
	my ($self, $index) = @_;

	# Set up the table list of needbe
	if (not $self->{table_list}) {
		$self->FIRSTKEY;
	}

	if ($self->{table_list}->{$index}) {
		# Skip the table check
		return $self->{storm}->get($index, 1);
	} else {
		return $self->{storm}->get($index);
	}
}

=begin NaturalDocs

Method: EXISTS (private instance)

  Check for the existence of a table on a particular connection.

Parameters:

  String $index - The name of the table to check

Returns:

  Boolean - Whether the table exists

=end NaturalDocs

=cut

sub EXISTS {
	my ($self, $index) = @_;

	# Set up the table list of needbe
	if (not $self->{table_list}) {
		$self->FIRSTKEY;
	}

	if ($self->{table_list}->{$index}) {
		# Table exists in table list
		return 1;
	} else {
		return $self->{storm}->_sqldriver()->table_exists(
			$self->{storm}->dbi, $index
		);
	}
}

=begin NaturalDocs

Method: FIRSTKEY (private instance)

  Reset the iterator and return the first hash object.

  The tables are returned in a random order.

Parameters:

  None

Returns:

  String - the table name
  Object - Table as a DBIx::StORM::Table (list context only)

=end NaturalDocs

=cut

sub FIRSTKEY {
	my $self = shift;
	$self->{table_list} = $self->{storm}->_sqldriver()->table_list(
		$self->{storm}->dbi
	);

	# Only return a value if not being called in void context
	if (defined wantarray) {
		# Reset iterator
		keys %{ $self->{table_list} };
		return $self->NEXTKEY;
	}
}

=begin NaturalDocs

Method: NEXTKEY (private instance)

  Return the next table from the iterator.

  The tables are returned in a random order.

Parameters:

  None

Returns:

  String - the table name
  Object - Table as a DBIx::StORM::Table (list context only)

=end NaturalDocs

=cut

sub NEXTKEY {
	my $self = shift;
	return unless $self->{table_list};
	my($key,undef) = each %{ $self->{table_list} };

	return $key unless wantarray;
	return map { $_, $self->FETCH($_) } $key;
}

=begin NaturalDocs

Method: SCALAR (private instance)

  Return the number of tables available on the connection.

Parameters:

  None

Returns:

  Integer - the number of tables available

=end NaturalDocs

=cut

sub SCALAR {
	my $self = shift;
	return scalar $self->{storm}->_sqldriver()->table_list(
		$self->{storm}->dbi);
}

1;
