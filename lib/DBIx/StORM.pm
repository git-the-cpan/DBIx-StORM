#!/usr/bin/perl

package DBIx::StORM;

=begin NaturalDocs

Class: DBIx::StORM

A StORM class representing a database connection.

This is essentially a wrapper for a DBI connection. This object can be
dereferenced as a hash, with the keys of the hash being the table names
present in this database and the values being DBIx::StORM::Table
objects.

=end NaturalDocs

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;

use overload '%{}'    => "_as_tied_hash",
             fallback => 1;

use Carp;
use DBI;
use Scalar::Util qw(weaken);

use DBIx::StORM::SQLDriver;
use DBIx::StORM::Table;

=begin NaturalDocs

Variable: $VERSION (public static)

  The version of this package.

=end NaturalDocs

=cut

our $VERSION = '0.10';

=begin NaturalDocs

Integer: $DEBUG (public static)

  Causes DBIx::StORM to emit debug messages if set to a true value.
  These are different from warnings which can be enabled/disabled using
  the warnings pragma.

=end NaturalDocs

=cut

our $DEBUG = 0;

=begin NaturalDocs

Method: connect (public static)

  Create a new DBIx::StORM object and open a connection to the database
  using DBI. All of the parameters are passed to DBI untouched.

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

	# Set up the DBI connection
	my $dbh = DBI->connect(@_);
	return unless ref $dbh;

	return $class->_wrap_handle($dbh);
}

=begin NaturalDocs

Method: connect_cached (public static)

  Create a new DBIx::StORM object using connection to the database
  using DBI. If there is already an open connection to the database
  requested then it will be reused, otherwise a new connection will
  be established. All of the parameters are passed to DBI untouched.

Parameters:

  String $dsn - The DBI DSN string or a DBI::db object
  String $user - Database username (if $dsn is a string)
  String $password - Database password (if $dsn is a string)

Returns:

  Object - A new DBIx::StORM object

=end NaturalDocs

=cut

sub connect_cached {
	my $class = shift;

	# Set up the DBI connection
	my $dbh = DBI->connect_cached(@_);
	return unless ref $dbh;

	return $class->_wrap_handle($dbh);
}

=begin NaturalDocs

Method: _wrap_handle (private static)

  Create a new DBIx::StORM object from an existing DBI handle.

  This is used by the constructors connect() and connect_cached() to
  make a fully-fledged StORM handle.

Parameters:

  Object $dbi - An instance of DBI::dbh to wrap

Returns:

  Object - A new DBIx::StORM object, using $dbi for database access

=end NaturalDocs

=cut

sub _wrap_handle {
	my ($class, $dbh) = @_;

	# $self is a reference to a reference to a hash. It is not a
	# hash reference because it is difficult to use a hash object
	# in combination with overloaded hash dereferencing.
	my $self = \{ dbih => $dbh };

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
			$dbh->set_err(1, $@);
			return;
		}

		$class->_debug("Couldn't find a suitable SQL " .
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
	my ($self, $table_name) = @_;

	# Return a cached object if we can, otherwise make a new one
	# I tried to do this in one statement, but dropped the object
	# on the way.
	if ($$self->{cache}->{tables}->{$table_name}) {
		return $$self->{cache}->{tables}->{$table_name};
	} else {
		# Check if said table exists
		if (not $$self->{sqldriver}->table_exists(
				$self->dbi, $table_name
			)) {
			$self->dbi->set_err(1,
				"No such table: $table_name\n");
		}

		my $table = $$self->{cache}->{tables}->{$table_name} =
			DBIx::StORM::Table->_new($self, $table_name);
		weaken($$self->{cache}->{tables}->{$table_name});
		return $table;
	}
}

=begin NaturalDocs

Method: _as_tied_hash (private instance)

  Fetch a tied hash map of table name to DBIx::StORM::Table objects.

Parameters:

  None

Returns:

  Hash - A map of string table names to DBIx::StORM::Table objects. This is a
         tied hash of class DBIx::StORM and uses lazy lookup.

=end NaturalDocs

=cut

sub _as_tied_hash {
	my $self = shift;
	return $$self->{tied} if $$self->{tied};
	tie my %tied, "DBIx::StORM", $self;
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

	croak("Bad hint; must be key=>value format") if (@_ % 2);

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

	print STDERR @_ if ($DEBUG);
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

=begin NaturalDocs

Method: TIEHASH (private static)

  Create a new tied hash of StORM Table objects available on this
  handle.

Parameters:

  Object $storm - The DBIx::StORM connection object

Returns:

  Object - $storm, which will be used as the underlying object for the
           tie.

=end NaturalDocs

=cut

sub TIEHASH {
	my ($class, $storm) = @_;
	return $storm;
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

	return $self->get($index);
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

	return $self->_sqldriver()->table_exists($self->dbi, $index);
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

	$self->{table_list} = $self->_sqldriver()->table_list(
		$self->dbi
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
	return scalar $self->_sqldriver()->table_list($self->dbi);
}

1;
__END__

=head1 NAME

DBIx::StORM - Perl extension for object-relational mapping

=head1 SYNOPSIS

  use DBIx::StORM;

  my $connection = DBIx::StORM->connect($dbi_dsn, $user, $password);
  my $table = $connection->{table_name};

=head1 DESCRIPTION

DBIx::StORM is an object-relational mapper designed to provide easy
database-vendor-independent access to a DBI-accessible database by
allowing you to access a relational database in an object-oriented
fashion, using perl expressions to specify your criteria.

If you'd like to know what makes DBIx::StORM different from other ORMs
then please see L<DESIGN PRINCIPLES> below.

If you're after a quick-start guide please see
L<DBIx::StORM::Tutorial>.

=head1 DESIGN PRINCIPLES

=over

=item * Gets to work quickly with your database

DBI::StORM is designed to work around your database. You don't have to
follow any naming conventions on your tables or columns.  The module
will find out the primary and foreign keys in your database, and will
help you walk the foreign keys.

If your database schema is lacking the necessary metadata you can point
the module in the right direction with the C<$dbix_storm-E<gt>add_hint>
method.

=item * Connection-centric, not class-centric

Tables are accessed via the connection object and not via a specific
class, which makes it easy to access new tables. If you want to set up
a class that maps to a given table, you can use the helper class to do
this.

=item * Finding and sorting should follow perl

DBIx::StORM provides the C<grep> and C<sort> methods which like the perl
operators accept a subroutine reference that can do whatever you want
them to. No passing round chunks of SQL, custom pseudo-code or lists of
string operators. Your perl subs are syntax-checked at compile time just
as normal.

=item * But this shouldn't come at the cost of performance

DBIx::StORM will examine your subroutines and understand what it is
trying to do. It can then turn it into SQL and use the power of the
database to your advantage. This gives you the best of both worlds -
the portability of perl code to query the database, but the performance
of the native database query.  Judicious use of caching means that the
subroutine should only be compiled when needed.

=item * Objects should feel like corresponding perl datatypes

Using perl's overloading, you can examine the tables in a connection by
treating it like a hash reference, a result set works like an array reference
and a record works like a hash reference. You get the power of standard
perl functions to access your data.

=back

=head1 THE DBIx::StORM OBJECT

This class is the base of the StORM ORM system. This class represents a
database connection.

You can dereference this object to access a hash. The hash keys are the
string names of the tables available on this connection, and the values
are the corresponding DBIx::StORM::Table objects.

=head2 METHODS

=head3 CONNECT

  DBIx::StORM->connect($dsn, $user, $password)

Build a new DBIx::StORM by establishing a DBI connection to $dsn using
username $user and password $password. Returns a new object on success
or undef on failure.

=head3 CONNECT_CACHED

  DBIx::StORM->connect($dsn, $user, $password)

Build a new DBIx::StORM by establishing a DBI connection to $dsn using
username $user and password $password. This uses L<DBI>'s
C<connect_cached()> call that will re-use an existing database
connection if appropriate, instead of unconditionally creating a new
one. Returns a new object on success or undef on failure.

=head3 DBI

  $dbix_StORM->dbi()

Retrieve the DBI object underpinning this connection object.

=head3 GET

  $dbix_StORM->get($tablename)

Access a DBIx::StORM::Table object for table $tablename on this
connection.  Returns undef on failure or if no such table exists.

=head3 ADD_HINT

  $dbix_StORM->add_hint($type => $hint [, $type => $hint ... ])

Add a hint to the StORM's metadata. This is typically used to add
foreign key information for database systems that don't natively
support them.

=head2 VARIABLES

=head3 $DEBUG

If set to a true value the DBIx::StORM framework will emit additional
messages to STDERR which may be useful in debugging issues.

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
