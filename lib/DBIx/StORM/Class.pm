#!/usr/bin/perl

package DBIx::StORM::Class;

=begin NaturalDocs

Class: DBIx::StORM::Class

A base class that can be used to turn a DBIx::StORM::Table into a class in
another package.

This class inherits from DBIx::StORM::Record and adds methods to access the
records in a given table. Any records accessed will be automatically blessed
into this class.

=end NaturalDocs

=cut

use strict;
use warnings;

use base "DBIx::StORM::Record";

use DBIx::StORM;

=begin NaturalDocs

Method: config (protected static)

  Configure this class to specify connection and table information

Parameters:

  Hash - Configuration information for this class

Returns:

  Nothing

=end NaturalDocs

=cut

sub config {
	my $package = shift;
	my $glob = $package->__dbix_storm_get_config_glob;

	$glob->{HASH} = { @_ };
}

=begin NaturalDocs

Method: __dbix_storm_get_config_glob (private static/instance)

  Fetch the glob which contains the configuration hash

Parameters:

  None

Returns:

  GlobRef - the glob containing the configuration hash

=end NaturalDocs

=cut

sub __dbix_storm_get_config_glob {
	my $package = shift;
	no strict "refs";
	return *{ $package . "::__DBIX_STORM_CONFIG" };
}

=begin NaturalDocs

Method: __dbix_storm_get_config (private static/instance)

  Fetch the configuration hash

Parameters:

  None

Returns:

  HashRef - configuration information as passed to config()

=end NaturalDocs

=cut

sub __dbix_storm_get_config {
	my $package = shift;
	my $glob = $package->__dbix_storm_get_config_glob;
	die("No config") unless $glob->{HASH};
	return $glob->{HASH};
}

=begin NaturalDocs

Method: __dbix_storm_make_connect (private static/instance)

  Return an active DBIx::StORM object for this class. This may have been
  cached from an earlier call.

Parameters:

  None

Returns:

  Object - DBIx::StORM connection

=end NaturalDocs

=cut

sub __dbix_storm_make_connect {
	my $package = shift;
	use Carp;
	
	my $config = $package->__dbix_storm_get_config;
	if ($config->{live_connection}) { return $config->{live_connection} };
	
	my $connection;
	my $conndetails = $config->{connection};

	no strict "refs";
	if (@{ $package . "::ISA" } and not $conndetails) {
		# Check to see if a parent package is not DBIx::StORM::Class
		# (it must be a subclass) but can make a connection. If so,
		# go grab their connection to implement connection
		# inheritence.
		foreach my $parent (@{ $package . "::ISA" }) {
			next if ($parent eq "DBIx::StORM::Class");

			if ($parent->can("__dbix_storm_make_connect")) {
				my $connection =
					$parent->__dbix_storm_make_connect();
				if ($connection) {
					$config->{live_connection} =
						$connection;

					# Take a reference to the bless map
					$config->{bless_map} = $parent->__dbix_storm_get_config()->{bless_map};
					# And insert myself
					$config->{bless_map}->{$config->{table}} = $package if exists $config->{table};
					return $connection;
				}
			}
		}
	}

	use strict "refs";

	die("No connection details given for package $package") unless $conndetails;
	if (ref $conndetails eq "CODE")  { $connection = &$conndetails; }
	elsif (ref $conndetails eq "ARRAY") {
		$connection = DBIx::StORM->connect(@$conndetails)
	} else {
		no strict "refs";
		$connection = $conndetails->__dbix_storm_make_connect();
	}

	die("Error creating connection") unless $connection;

	if ($config->{hints}) {
		my @hints = @{ $config->{hints} };
		while(@hints) {
			$connection->add_hint(shift(@hints) =>
				shift(@hints));
		}
	}

	if (my $infs = $config->{inflater}) {
		if (ref $infs) {
			$connection->inflater($_) foreach(@$infs);
		} else {
			$connection->inflater($_) foreach($infs);
		}
	}

	$config->{bless_map} = { };
	$config->{bless_map}->{$config->{table}} = $package
		if exists $config->{table};
	$config->{live_connection} = $connection;
	return $connection;
}

=begin NaturalDocs

Method: all (public static)

  Fetch a RecordSet of all the records in the table this class back on to.

Parameters:

  None

Returns:

  Object - DBIx::StORM::RecordSet of the records in the table

=end NaturalDocs

=cut

sub all {
	my $package = shift;
	my $config = $package->__dbix_storm_get_config;
	my $connection = $package->__dbix_storm_make_connect;

	my $table = $connection->{$config->{table}};
	die("Error getting table") unless $table;

	# Let the table know magic is afoot!
	$table->{bless_map} = $config->{bless_map};
	return $table;
}

sub connection {
	my $package = shift;

	return $package->__dbix_storm_make_connect;
}

=begin NaturalDocs

Method: grep (public static)

  Fetch a RecordSet of all the records in the table this meet the criteria
  of the filter $sub.

Parameters:

  CodeRef $sub - A filter subroutine that returns true for rows to be included

Returns:

  Object - DBIx::StORM::RecordSet of the records in the table that match

=end NaturalDocs

=cut

sub grep {
	my $package = shift;
	return $package->all->grep(@_);
}

=begin NaturalDocs

Method: _init (protected instance)

  Initialise a newly created object of this class. This differs to new in
  that new is called only for newly-created records that start life outside
  the database, while _init is called for all records including those
  fetched from the database.

  Currently is does nothing, but is here so that it can be subclassed.

Parameters:

  None

Returns:

  Nothing

=end NaturalDocs

=cut

sub _init {
	# Do nothing
}

=begin NaturalDocs

Method: serialise (public instance)

  Serialise an object to a string description which can be used to fetch
  it back from the database later.

  By default, it serialises to the value of the primary key columns, joined
  with a comma. Any commas or backslashes in these values are
  backslash-escaped

Parameters:

  None

Returns:

  String - a serialised representation of this object

=end NaturalDocs

=cut

sub serialise {
	my $self = shift;

	# A deleted row would be bad here
	$self->_not_invalid();

	# Can we serialise as a primary key?
	if (defined($$self->{table}) and
            my $pk = $$self->{table}->primary_key) {

		# Our intention is to join together the PK values with commas
		my @ret;
		foreach my $p (@$pk) {
			$p =~ s/^.*->//;
			my $ret = $self->get($p);
			return if not defined $ret;
			# Escape
			$ret =~ s/\\/\\\\/;
			$ret =~ s/,/\\,/;
			push @ret, $ret;
		}
		return join ",", @ret;
	}

	# No PK, so undef
	return;
}

=begin NaturalDocs

Method: unserialise (public static)

  Recreate an object using the string obtained from serialise() and the
  database.

  Currently not implemented.

Parameters:

  String $string - the serialised representation of the object

Returns:

  Object - a record blessed into this package

=end NaturalDocs

=cut

sub unserialise {
	my ($package, $string) = @_;

	# We want to split on commas, but only those where there are zero
	# or an even number of backslashes preceding it (ie. it isn't
	# escaped)
	my @in_process = split /(,|\\)/, $string;

	my @pk_bits;
	my $current_token = "";
	for(my $l = 0; $l <= $#in_process; ++$l) {
		local $_ = $in_process[$l];
		if ($_ eq ",") {
			push @pk_bits, $current_token;
			$current_token = "";
		} elsif ($_ eq "\\") {
			my $next_token = $in_process[$l+1];
			next unless defined $next_token;
			if ($next_token eq "\\") {
				$current_token .= "\\";
				# Skip next token
				++$l;
			} elsif ($next_token eq ",") {
				$current_token .= ",";
				# Skip next token
				++$l;
			}
		} else {
			$current_token .= $_;
		}
	}
	push @pk_bits, $current_token;

	# Good, @pk_bits should specify the primary key values of the field
	# that we want to select. Now we just need to ask the database for
	# it.

	# Which are the PK columns? Copy to avoid damaging it
	my $table = $package->__dbix_storm_make_connect->{
		$package->__dbix_storm_get_config->{table}
	};
	my $pk = $table->primary_key;
	$pk = [ @$pk ];

	# Build the where clause that matches the primary key
	my @where;
	foreach(@$pk) {
		my $sql_col = $_;
		$sql_col =~ s/.*->//;

		push @where, [ "$sql_col = ?", shift(@pk_bits) ];
	}

	# OK, now run the query and get a new table mapping and statement
	# handle
	my ($sth, $table_mapping) = $table->_storm->_sqldriver->do_query({
	        required_columns => [ @$pk ],
	        recommended_columns => undef,
	        table => $table,
	        wheres => \@where,
		views => undef,
		record_base_reference => $table->name
        });

	# We should have got a row - panic if not!
	return if ($sth->rows == 0);
	my $row = [ $sth->fetchrow_array ];
	return unless @$row;

	# At least one DBD returns a row of all undefs if you get zero
	# results (yuck). We ought to get back some set PK fiekds, so weed
	# this out.
	return unless grep { defined } @$row;

	# Inflate the row using the connection's inflater if specified
	if (my @i = $table->_storm->_inflaters) {
		foreach(@i) {
			$row = $_->inflate($table->_storm, $row, $sth,
				$table_mapping);
		}
	}

	# Make the actual record
	return $package->_new({
                table          => $table,
                content        => $row,
                base_reference => $table->name,
                resultset      => $table,
                table_mapping  => $table_mapping
        });
}

=begin NaturalDocs

Method: new (public static)

  Create a new record object blessed into this class which will be stored
  in the underlying table.

Parameters:

  None

Returns:

  Object - a record blessed into this package

=end NaturalDocs

=cut

sub new {
	my $package = shift;
	return $package->all->insert();
}

=begin NaturalDocs

Method: _stash (protected static)

  As objects in this class are DBIx::StORM::Records too, you cannot directly
  change the hash entries as this would change the database. This method
  returns a hash scratchpad which can be edited to store data. It will not
  be saved between sessions.

Parameters:

  None

Returns:

  HashRef - an in-memory scratchpad for this object

=end NaturalDocs

=cut

sub _stash {
	my $self = shift;
	return unless ref $self;
	$$self->{__class_stash} ||= {};
	return $$self->{__class_stash};
}

1;
__END__

=head1 NAME

DBIx::StORM::Class - A parent class for classes that would like to back
onto a DBIx::StORM::Table and have records blessed into their own
class.

=head1 SYNOPSIS

  package MyClass;
  use base "DBIx::StORM::Class";

  __PACKAGE__->config(
    connection => ["DBI:mysql:database=mydb", "username", "password"],
    table      => "MyTable",
  );

=head1 DESCRIPTION

This is a base class that can be used to turn a DBIx::StORM::Table into
a class in another package.

This class inherits from DBIx::StORM::Record and adds methods to access the
records in a given table. Any records accessed will be automatically blessed
into this class.

You can extend your subclass to add new methods for your class. You can also
use a private stash to store transient information on your object.

=head2 METHODS

=head3 CONFIG

A static method to set up the class. It takes a hash which supports the
following keys

=over

=item * connection (required)

Specify connection information. This is usually an array reference of the
parameters to be passed to DBI->connect, but could also be a string
which is treated as a package name of another DBIx::StORM::Class subclass
to borrow the connection from, or a subroutine reference which must return
an object of class DBIx::StORM.

=item * table (required)

The string name of the table to store objects of this class in to. It must
be available on the connection specified above.

=back

=head3 NEW

This constructor is used to create new record objects before they are
inserted into the database. You can subclass this to initialise new
objects, and then write the record to the database by using the
inherited commit call.

=head3 _INIT

This method is called after construction of a record object. Unlike
new() it is also called for objects that are created from an existing
database record. The default method does nothing, but you can override
it to add additional initialisation.

=head3 _STASH

Returns a hash reference to a private per-object data store. It is 
in-memory and is not stored across sessions, but can be used by the
subclass to hold transient data.

=head3 ALL

Returns a DBIx::StORM::RecordSet of all the records in the table. Each
record belongs to the subclass and can have subclass methods called on
them.

=head3 GREP

Accepts a code reference as a filter and returns a DBIx::StORM::RecordSet
for records in the table for which the filter returns true. Each
record belongs to the subclass and can have subclass methods called on

=head1 SEE ALSO

  L<DBI>
  L<DBIx::StORM>
  L<DBIx::StORM::Record>
  L<DBIx::StORM::RecordSet>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.nameE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
