#!/usr/bin/perl

package DBIx::StORM::Table;

=begin NaturalDocs

Class: DBIx::StORM::Table

An StORM class representing a table.

This class inherits from DBIx::StORM::RecordSet, so can be grep'd (filtered),
sorted and viewed. You can also insert new rows. Tables can be array
dereferenced to iterate over the rows in the table.

=end NaturalDocs

=cut

use strict;
use warnings;
use base "DBIx::StORM::RecordSet";

use Carp;
use DBIx::StORM::FilteredRecordSet;
use DBIx::StORM::OrderedRecordSet;
use DBIx::StORM::RecordArray;
use DBIx::StORM::RecordSetWithView;

=begin NaturalDocs

Method: _new (private instance)

  Create a new DBIx::StORM::Table object from a connection.

Parameters:

  Object $storm  - A connection of type <DBIx::StORM>
  String $table - The table name as a string

Returns:

  Object - A new DBIx::StORM::Table object

=end NaturalDocs

=cut

sub _new {
	my ($class, $storm, $table) = @_;

	my $self = {
		storm => $storm,
		table => $table,
	};

	return bless $self => $class;
}

=begin NaturalDocs

Method: _get_sth (private instance)

  Actually run the query using the DBI and the SQLDriver and return a result
  statement handle. This is a simpler, speedier version of that in
  DBIx::StORM::RecordSet.

Parameters:

  None

Returns:

  Object - The DBI statement handle of results
  Hash - A hash map of column references to result array indices

=end NaturalDocs

=cut

sub _get_sth {
	my $self = shift;

	# If we've got here, then someone is requesting either the entire
	# table, or the filter failed to compile.
	return $self->_storm->_sqldriver->do_query({
		required_columns => $self->primary_key,
		recommended_columns => $self->_recommended_columns,
		table => $self
	});
}

=begin NaturalDocs

Method: name (public instance)

  Get the name of the table this object represents

Parameters:

  None

Returns:

  String - The table name as a string

=end NaturalDocs

=cut

sub name {
	my $self = shift;
	return $self->{table};
}

=begin NaturalDocs

Method: insert (public instance)

  Insert a new row into the table

Parameters:

  Subref - A subroutine that initialises the new record, $_ (optional)

Returns:

  Object - A row of type DBIx::StORM::Record

=end NaturalDocs

=cut

sub insert {
	my ($self, $sub) = @_;

	# Build a new record for this table
	my $record = DBIx::StORM::Record->_new({
		table          => $self,
		resultset      => $self,
		base_reference => $self->name()
	});

	# To do here - parse $sub and cache if appropriate
	if ($sub) {
		if (ref $sub eq "HASH") {
			while(my($field,$value) = each %$sub) {
				$record->{$field} = $value;
			}
		} else {

			local $_ = $record;
			&$sub;
		}
		# Save any changes from the initialiser and
		# make sure we save any future changes too, now it
		# is inserted
		$record->autocommit(1);
	}

	return $record;
}

=begin NaturalDocs

Method: _filter_id (private instance)

  All RecordSets need a unique string identifier which is used for caching.

  For tables this is the table name.

Parameters:

  None

Returns:

  String - A cachable identifier for this RecordSet configuration

=end NaturalDocs

=cut

sub _filter_id {
	my $self = shift;
	return $self->name;
}

=begin NaturalDocs

Method: primary_key (public instance)

  Fetch a list of all the primary key column names in this table.

Parameters:

  None

Returns:

  List - String column names of the primary keys

=end NaturalDocs

=cut

sub primary_key {
	my $self = shift;
	return $self->_storm->_sqldriver->primary_key($self);
}

=begin NaturalDocs

Method: foreign_keys (public instance)

  Fetch a hash of all the foreign keys in this table.

  The hash key is the string name of the foreign key column in this table,
  and the value is a table reference to the column in the foreign table.

Parameters:

  None

Returns:

  HashList - Details of the foreign keys used by this table.

=end NaturalDocs

=cut

sub foreign_keys {
	my $self = shift;
	return $self->_storm->_sqldriver->foreign_keys($self);
}

=begin NaturalDocs

Method: grep (public instance)

  Filter this DBIx::StORM::RecordSet by applying a result filter.

Parameters:

  SubRef - The filter code as a perl subroutine reference

Returns:

  Object - A new DBIx::StORM::RecordSet which contains just the matching rows

=end NaturalDocs

=cut

sub grep {
	my $self = shift;
	my $filter = shift;

	return DBIx::StORM::FilteredRecordSet->_new({
		@_,
		filter           => $filter,
		parent           => $self,
		table            => $self,
		required_columns => [ @{ $self->primary_key } ],
		storm            => $self->_storm,
		wheres           => [ ],
		sorts            => [ ],
		views            => { },
		perl_wheres      => [ ],
		perl_sorts       => [ ],
		perl_views       => { }
	});
}

=begin NaturalDocs

Method: sort (public instance)

  Sort this DBIx::StORM::RecordSet by applying a sort routine.

Parameters:

  SubRef - The sort code as a perl subroutine reference, similiar to the one used in perl's sort operator

Returns:

  Object - A new DBIx::StORM::RecordSet which contains the same rows sorted

=end NaturalDocs

=cut

sub sort {
	my $self = shift;
	my $filter = shift;

	return DBIx::StORM::OrderedRecordSet->_new({
	        @_,
	        filter           => $filter,
	        parent           => $self,
	        table            => $self,
	        required_columns => [ @{ $self->primary_key } ],
	        storm            => $self->_storm,
	        wheres           => [ ],
	        sorts            => [ ],
	        views            => { },
	        perl_wheres      => [ ],
	        perl_sorts       => [ ],
	        perl_views       => { }
	});
}

=begin NaturalDocs

Method: view (public instance)

  Create a new DBIx::StORM::RecordSet with derivable columns added.

Parameters:

  HashList - The keys in this has the names of the column to create. The value may either be a perl subref which defines how the column is calculated, or a string containing a SQL snippet to generate the column

Returns:

  Object - A new DBIx::StORM::RecordSet which contains the same rows with the new columns added

=end NaturalDocs

=cut

sub view {
	my $self = shift;
	my $new_views = { @_ };

	return DBIx::StORM::RecordSetWithView->_new({
	        parent           => $self,
	        table            => $self,
	        required_columns => [ @{ $self->primary_key } ],
	        storm            => $self->_storm,
	        new_views        => $new_views,
	        wheres           => [ ],
	        sorts            => [ ],
	        views            => { },
	        perl_wheres      => [ ],
	        perl_sorts       => [ ],
	        perl_views       => { }
	});
}

=begin NaturalDocs

Method: grep_pp (public instance)

  Filter this DBIx::StORM::RecordSet using a perl filter. This is identical
  to the <grep> method, but does not attempt to parse the subref and
  optimise it.

Parameters:

  SubRef - The filter code as a perl subroutine reference

Returns:

  Object - A new DBIx::StORM::RecordSet which contains just the matching rows

=end NaturalDocs

=cut

sub grep_pp {
	my ($self, @filter) = @_;
	return $self->filter(@filter, perl_filter => 1);
}

sub _build_result_identity {
	my ($self, $record) = @_;

	# Which are the PK columns?
	my $pk = $self->primary_key;
	$pk = [ @$pk ];

	# The result should have a table mapping so we can work out
	# which tables we need to rebuilt
	die("no table mapping") unless $$record->{table_mapping};

	# Build the where clause that matches the primary key
	my @where;
	foreach(@$pk) {
		my $sql_col = $_;
		$sql_col =~ s/.*->//;
		my $ref_col = $$record->{base_reference} . "->$sql_col";

		# To get the content we need to index the array based on
		# the table mapping.
		push @where, [ "$sql_col = ?", $$record->{content}->[
		        $$record->{table_mapping}->{$ref_col}
		] ];
	}

	return (\@where, $pk);
}

=begin NaturalDocs

Method: _rebuild_record (private instance)

  This is called by a DBIx::StORM::Record when the content has changed or
  the column set loaded is incorrect. It causes the object to be rebuilt
  with a new set of column. The object is modified in-situ. The row is selected
  from the database by primary key column equality, so it won't work on
  tables without a PK.

Parameters:

  Object $record - DBIx::StORM::Record to rebuild
  Boolean $full - Whether to fetch all rows, or just the ones requested by the record object

Returns:

  None

=end NaturalDocs

=cut

sub _rebuild_record {
	my $self = shift;
	my $record = shift;
	my $full = 1;

	# Which columns do we want to build
	my $recommended_columns = $full ? undef : [ keys(%{ $$record->{content} }) ];

	my($wheres, $pk) = $self->_build_result_identity($record);

	# OK, now run the query and get a new table mapping and statement
	# handle
	my ($sth, $table_mapping) = $self->_storm->_sqldriver->do_query({
	        required_columns => [ @$pk ],
	        recommended_columns => $recommended_columns,
	        table => $self,
	        wheres => $wheres,
		views => undef,
		record_base_reference => $$record->{base_reference}
        });

	# We should have got a row - panic if not!
	my $row = [ $sth->fetchrow_array ];
	unless($row) {
		$self->_storm->dbi->set_err(1, "No row to rebuild record from - is the primary key properly defined?");
		return;
	}

	# Inflate the row using the connection's inflater if specified
	if (my @i = $self->_storm->_inflaters) {
		foreach(@i) {
			$row = $_->inflate($row, $sth, $table_mapping);
		}
	}

	# Ask the record to update itself with the new result
	$record->_update_content($row, $table_mapping);
}

=begin NaturalDocs

Method: _get_record_for_fk (private instance)

  When a foreign key column in a Record from this table is access, this
  method is called to generate the Record record for the foreign key.

Parameters:

  String $column - the name of the foreign key column
  String $value - the value of the column in the calling record
  Object $resultset - the resultset that the calling record came from
  String $base_ref - the path to the table the calling record comes from
  HashRef $table_mapping - the calling record's mapping of column references to content indexes
  ArrayRef $content - The column values contained in the calling record

Returns:

  Object - A DBIx::StORM::Record

=end NaturalDocs

=cut

sub _get_record_for_fk {
	my ($self, $column, $value, $resultset, $base_ref,
	    $table_mapping, $content) = @_;

	# We need copies of these as we may well mash them
	$content = [ @$content ];
	$table_mapping = { %$table_mapping };

	# We need to update the table mapping so the new result knows it's 
	# own base_ref
	if (not $table_mapping->{"$base_ref->$column"}) {
		push @$content, $value;
		$table_mapping->{ "$base_ref->$column" } = $#{ $content };
	}

	# Build the new result. The SQLDriver will take care of the rest
	my $result = DBIx::StORM::Record->_new({
	        table => $self,
	        content => $content,
	        table_mapping => $table_mapping,
	        resultset => $resultset,
	        base_reference => $base_ref
	});
}

=begin NaturalDocs

Method: _table (private instance)

  All RecordSets need to be able to quickly fetch the underlying
  DBIx::StORM::Table object it is derived from.

  In the case of DBIx::StORM::Table this is the object itself.

Parameters:

  None

Returns:

  Object - Object of type DBIx::StORM::Table

=end NaturalDocs

=cut

sub _table {
	my $self = shift;
	return $self;
}

=begin NaturalDocs

Method: identity (public instance)

  Fetch the record that has a given primary key value. For one-column primary
  keys you can pass in the value directly. Otherwise a hash reference should
  be passed in of field name => field value mappings.

  If you incorrectly specify the primary key this function will die.

Parameters:

  $primary_key_info - Either a value or hashref specifying the primary key
                      value(s) of the desired Record.

Returns:

  Object - Object of type DBIx::StORM::Record

=end NaturalDocs

=cut

sub identity {
	my ($self, $primary_key_info) = @_;

	my @wheres;

	my $pks = $self->primary_key;
	if (not ref $primary_key_info) {
		croak("Multi-column primary key in table " . $self->name . 
		    " but only one identity value specified")
			if (@$pks != 1);

		my $pk = $pks->[0];
		$pk =~ s/.*->//;

		push @wheres, [ $pk . " = ?", $primary_key_info];
	} else {
		foreach my $field (@$pks) {
			$field =~ s/.*->//;
			if (not exists $primary_key_info->{$field}) {
				croak("Field $field is part of primary key in " .
				    $self->name . "but was not specified");
			}

			push @wheres, [ "$field = ?",
				$primary_key_info->{$field} ];
		}
	}

	my ($sth, $table_mapping) = $self->_storm->_sqldriver->do_query({
	        required_columns => [ ],
		recommended_columns => undef,
	        table => $self,
	        wheres => \@wheres,
		record_base_reference => $self->name
        });
	my $row = [ $sth->fetchrow_array ];

	return unless $row;

	my $result = DBIx::StORM::Record->_new({
	        table          => $self,
	        content        => $row,
	        table_mapping  => $table_mapping,
	        resultset      => $self,
	        base_reference => $self->name
	});
}

1;
__END__

=head1 NAME

DBIx::StORM::Table - An object-based representation of a database table

=head1 SYNOPSIS

  my $table = $connection->{table_name};

  foreach my $record (@$table) {
    print "The ID column for this record is " . $record->{id} . "\n";
  }

=head1 DESCRIPTION

A table is a type of <DBIx::StORM::RecordSet> so the methods defined by
it may be used as well. This includes the ability to stringify it to
print the primary key, and the ability to treat it as an array reference
to foreach over.

You should not create objects of this class directly, but instead create
it from a <DBIx::StORM> object.

=head2 METHODS

=head3 NAME

  my $table_name = $storm->name();

Fetch the name of the database table that this object represents.

=head3 INSERT

  my $record = $storm_table->insert(sub { $_->id = 3; $_->name = "Camel" })

Return a new record of type <DBIx::StORM::Record>. Takes a subroutine reference
as a parameter which specifies how to initialise the object.

=head3 PRIMARY KEY

  my @pks = $storm_table->primary_key();

Fetch a list of column names which are primary key columns in the underlying
database table.

=head3 FOREIGN_KEYS

  my %fks = $storm_table->foreign_keys();

Fetch information on foreign keys in this table. The keys of the hash are
the column names in this table that are foreign keys. The values are the
details of the table referenced by the foreign key column, typically in
the format of "table_name->column_name".

=head1 SEE ALSO

  L<DBIx::StORM>
  L<DBIx::StORM::Record>
  L<DBIx::StORM::RecordSet>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.nameE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
