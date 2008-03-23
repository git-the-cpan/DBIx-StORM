#!/usr/bin/perl

package DBIx::StORM;

=begin NaturalDocs

Class: DBIx::StORM

A StORM class representing a database connection.

This is essentially a wrapper for a DBI connection. This object can be
dereferenced as a hash, with the keys of the hash being the table names
present in this database and the values being DBIx::StORM::Table
objects.

Any methods not used by this class will be passed to the underlying DBI
connection object, so you can call most DBI methods directly on this
object.

=end NaturalDocs

=cut

use 5.006;
use strict;
use warnings;

use overload '%{}'    => "_as_tied_hash",
             fallback => 1;

use Carp;
use DBI;

use DBIx::StORM::SQLDriver;
use DBIx::StORM::Table;
use DBIx::StORM::TiedTable;

=begin NaturalDocs

Variable: $VERSION (public static)

  The version of this package.

=end NaturalDocs

=cut

our $VERSION = '0.08';

=begin NaturalDocs

Integer: $DEBUG (public static)

  Used to set the level of debug messages output by the DBIx::StORM framework.
  Useful values are:

  0 - never output messages
  1 - output important messages, including those that seriously hurt performance
  2 - output useful messages that can explain how the system understands your code and what SQL is being executed
  3 - output even more messages; useful for internal debugging

=end NaturalDocs

=cut

our $DEBUG = 2;

=begin NaturalDocs

Method: connect (public static)

  Create a new DBIx::StORM object and open a connection to the database
  using DBI.

Parameters:

  String $dsn - The DBI DSN string or a DBI::db object
  String $user - Database username (if $dsn is a string)
  String $password - Database password (if $dsn is a string)

Returns:

  Object - A new DBIx::StORM object

=end NaturalDocs

=cut

sub connect {
	my $class = shift;

	# $self is a reference to a reference to a hash. It is not a
	# hash reference because it is difficult to use a hash object
	# in combination with overloaded hash dereferencing.
	my $self = \{ };

	# Set up the DBI connection
	my $dbh = DBI->connect(@_);
	return unless ref $dbh;
	$$self->{dbih} = $dbh;

	# Now create the DB compatibility object. This is used to build
	# queries in a database-specific fashion. The object class is
	# chosen based on the DBI driver name. If a specific driver
	# can't be found then a generic driver is instantiated instead.
	my $drivername = $dbh->{Driver}->{Name};
	$$self->{sqldriver} = eval "
		use DBIx::StORM::SQLDriver::$drivername;
		DBIx::StORM::SQLDriver::$drivername->new();
	";
	if ($@) {
		unless ($@ =~ m/Can't locate/) {
			$dbh->set_err(1,$@);
			return;
		}

		$class->_debug(1, "Couldn't find a suitable SQL " .
			"driver for $drivername\n"
		);
		$$self->{sqldriver} = DBIx::StORM::SQLDriver->new();
	}

	return bless $self => $class;
}

=begin NaturalDocs

Method: inflater (public instance)

  Add an inflater to the inflation chain for this connection. The
  inflater should be a subclass a DBIx::StORM::Inflater.

Parameters:

  Object $inf - The inflater object

Returns:

  Nothing

=end NaturalDocs

=cut

sub inflater {
	my ($self, $inf) = @_;
	push @{ $$self->{inflate} }, $inf if
		(ref($inf) and $inf->isa("DBIx::StORM::Inflater"));
}

=begin NaturalDocs

Method: _inflaters (private instance)

  Returns all the inflaters registered on this connection.

Parameters:

  None

Returns:

  List - List of DBIx::StORM::Inflater objects

=end NaturalDocs

=cut

sub _inflaters {
	my $self = shift;
	return @{ $$self->{inflate} } if $$self->{inflate};
	return ();
}

=begin NaturalDocs

Method: get (public instance)

  Fetch a table object using this database connection.

Parameters:

  String $table_name - The name of the table to open
  Boolean $skip_verify - Whether to skip checking for table existence

Returns:

  Object - A table object of class DBIx::StORM::Table

=end NaturalDocs

=cut

sub get {
	my ($self, $table_name, $skip_verify) = @_;

	if (not $skip_verify
		and not $$self->{sqldriver}->table_exists(
			$self->dbi, $table_name
		)) {
		$self->dbi->set_err(1, "No such table: $table_name\n");
	}

	# Now build the object
	return DBIx::StORM::Table->_new($self, $table_name);
}

=begin NaturalDocs

Method: _as_tied_hash (private instance)

  Fetch a tied hash map of table name to DBIx::StORM::Table objects.

Parameters:

  None

Returns:

  Hash - A map of string table names to DBIx::StORM::Table objects. This is a
         tied hash of class DBIx::StORM::TiedTable and uses lazy lookup

=end NaturalDocs

=cut

sub _as_tied_hash {
	my $self = shift;
	return $$self->{tied} if $$self->{tied};
	tie my %tied, "DBIx::StORM::TiedTable", $self;
	return $$self->{tied} = \%tied;
}

=begin NaturalDocs

Method: dbi (public instance)

  Fetch the underlying DBI database handle.

Parameters:

  None

Returns:

  Object - A scalar database handle of class DBI::db

=end NaturalDocs

=cut

sub dbi {
	my $self = shift;
	return $$self->{dbih};
}

=begin NaturalDocs

Method: add_hint (public instance)

  Add a hint to the key parsing system.

  The following hints are supported by all systems:

  o primary_key => "tableName->fieldName"
  o foreign_key => { "fromTable->field" => "toTable->field" }

Parameters:

  String $hint_type - a string describing the type of hint
  String $hint_value - the hint itself. The format depends on the <$hint_type>

Returns:

  Nothing

=end NaturalDocs

=cut

sub add_hint {
	my $self = shift;

	die("Bad hint; must be key=>value format") if (@_ % 2);

	while(@_) {
		my $hint_type = shift;
		my $hint_value = shift;

		$self->_sqldriver->add_hint($hint_type, $hint_value);
	}
}

=begin NaturalDocs

Method: _debug (private static/instance)

  Write a debugging message to STDERR if the debug level is high enough
  to warrant showing this message.

Parameters:

  Integer $level - an integer showing the level of this message. A higher number means the message is less likely to be shown
  List @messages - The message string(s) to be written to STDERR

Returns:

  Nothing

=end NaturalDocs

=cut

sub _debug {
	my $class = shift;
	my $level = shift;

	if ($level <= $DEBUG) {
		print STDERR @_;
	}
}

=begin NaturalDocs

Method: _sqldriver (private instance)

  Fetch the database driver used to perform database-specific functions and
  optimisations for this connection. This is used internally for other objects
  to be able to directly invoke database calls.

Parameters:

  None

Returns:

  Object - an instance of DBIx::StORM::SQLDriver

=end NaturalDocs

=cut

sub _sqldriver {
	my $self = shift;
	return $$self->{sqldriver};
}

1;
__END__

=head1 NAME

DBIx::StORM - Perl extension for object-relational mapping

=head1 SYNOPSIS

  use DBIx::StORM;

  my $connection = DBIx::StORM->connect($dbi_dsn, $username, $password);
  my $table = $connection->{table_name};

=head1 DESCRIPTION

The base of the StORM ORM system. This class represents a database
connection.

You can dereference this object to access a hash. The hash keys are the
string names of the tables available on this connection, and the values
are the corresponding DBIx::StORM::Table objects.

=head2 METHODS

=head3 CONNECT

  DBIx::StORM->connect($dsn, $user, $password)

Build a new DBIx::StORM by establishing a DBI connection to $dsn using
username $user and password $password. Returns a new object on success
or undef on failure.

=head3 DBI

  $dbix_StORM->dbi()

Retrieve the DBI object underpinning this connection object.

=head3 GET

  $dbix_StORM->get($tablename)

Access a DBIx::StORM::Table object for table $tablename on this connection.
Returns undef on failure or if no such table exists.

=head3 ADD_HINT

  $dbix_StORM->add_hint($type => $hint [, $type => $hint ... ])

Add a hint to the StORM's metadata. This is typically used to add foreign key
information for database systems that don't natively support them.

=head2 VARIABLES

=head3 $DEBUG

Used to set the level of debug messages output by the DBIx::StORM framework.

Useful values are:

  - 0: never output messages
  - 1: outputs important messages
  - 2: outputs useful messages
  - 3: outputs debugging messages

=head1 SEE ALSO

  L<DBI>
  L<DBIx::StORM::Table>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.nameE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
