#!/usr/bin/perl

package DBIx::StORM::RecordSet;

use strict;
use warnings;

use overload '@{}' => "_as_array",
             '""' => "_as_string";

use DBIx::StORM::FilteredRecordSet;
use DBIx::StORM::LexBindings;
use DBIx::StORM::OrderedRecordSet;
use DBIx::StORM::ParseCV;
use DBIx::StORM::RecordSetWithView;

=begin NaturalDocs

Variable: $filter_map (private static)

  An array of cached results from parsing perl subroutine references
  into SQL. The first level is a hash reference based on the usage of
  the subroutine (eg. filter, view, sort) and the next level is based
  on the stringified value of the code reference.

=end NaturalDocs

=cut

our $filter_map = { };

=begin NaturalDocs

Variable: $recommended_columns (private static)

  A cache of recommended columns for a given RecordSet. The first level
  is a hash reference of filter IDs, and each value is a hash of column
  names.

=end NaturalDocs

=cut

our $recommended_columns = { };

=begin NaturalDocs

Method: _do_parse (private instance)

  Inspect a filter target (may be a string for code reference) and
  decide how best to handle it. If it's a SQL string, it'll be fine
  as-is (it's up to you to make sure it works!) whilst if it's a perl
  CV it'll need parsing into SQL and caching for next time.

Parameters:

  Scalar $filter - The code reference or the string to parse
  String $mode - The type of parse required for perl (eg. select, view, order)

Returns:

  String - The result of the parse

=end NaturalDocs

=cut

sub _do_parse {
	my ($self, $filter, $mode, %settings) = @_;

	# A string filter is used as-is
	if (not ref $filter) {
		return $filter;
	}

	# We don't need to parse it if we're going to run it using perl
	if ($self->{perl_filter}) {
		return undef;
	}
	
	# Is it in the cache?
	my $parsed = $filter_map->{$mode}->{$filter};

	# Compile the code if we haven't seen this sub before
	unless (exists $filter_map->{$mode}->{$filter}) {
		$parsed = $self->_parse($filter, $mode);
	}

	# Now perform variable bindings. This changes for every time
	# the object is created, as the scratch pads are likely to have
	# been changed.
	if ($parsed and $settings{binding}) {
		my ($result) = $self->_do_binding($filter, $parsed, $mode);

		if (not $result) {
			return undef;
		}

		return $parsed;
	}

	return $parsed;
}

=begin NaturalDocs

Method: _parse (private instance)

  Actually parse a perl code reference and turn it into a glob of SQL

Parameters:

  CodeRef $filter - The code reference to parse
  String $mode - The type of parse required (eg. select, view, order)

Returns:

  String - The result of the parse

=end NaturalDocs

=cut

sub _parse {
	my ($self, $filter, $mode) = @_;

	# Invoke ParseCV to build it for us with the opcode map
	my $parsed = DBIx::StORM::ParseCV->parse($filter,
		$self->_storm->_sqldriver->opcode_map($mode));

	DBIx::StORM->_debug(2, "Parsing $filter in $mode: ",
		$parsed ? $parsed->[0]->toString : "(undefined)");
	return $parsed;
}

=begin NaturalDocs

Method: filter (public instance)

  Create a <DBIx::StORM::FilteredRecordSet> to represent a filtered set
  of results from the database. The filter is usually a perl subroutine
  reference with the filtering logic in it, but could be a SQL WHERE
  component where use of perl isn't appropriate.

Parameters:

  CodeRef $filter - The filter code as a code reference or string

Returns:

  Object - An object of type <DBIx::StORM::FilteredRecordSet>

=end NaturalDocs

=cut

sub grep {
	my ($self, $filter) = @_;

	# Build the new perl_ancestor value (ie. whether this object
	# or a parent has unbuildable subrefs)
	my $perl_ancestor = $self->{perl_filter} ||
		$self->{perl_ancestor};

	# Quite a few parameters need to be copied
	return DBIx::StORM::FilteredRecordSet->_new({
		@_,
		filter           => $filter,
		parent           => $self,
		required_columns => $self->{required_columns},
		storm            => $self->_storm,
		table            => $self->_table,
		perl_ancestor    => $perl_ancestor,
		wheres           => [ @{ $self->{wheres}      }],
		sorts            => [ @{ $self->{sorts}       }],
		views            => { %{ $self->{views}       }},
		perl_wheres      => [ @{ $self->{perl_wheres} }],
		perl_sorts       => [ @{ $self->{perl_sorts}  }],
		perl_views       => { %{ $self->{perl_views}  }},
	});
}

=begin NaturalDocs

Method: sort (public instance)

  Create a <DBIx::StORM::OrderedRecordSet> to represent the same records
  as in this object, but sorted into a particular order. The filter is
  usually a perl subroutine reference with the filtering logic in it, but
  could be a SQL ORDER BY component where use of perl isn't appropriate.

Parameters:

  $filter - The filter code as a code reference or string

Returns:

  Object - An object of type <DBIx::StORM::OrderedRecordSet>

=end NaturalDocs

=cut

sub sort {
	my ($self, $filter) = @_;

	# Build the new perl_ancestor value (ie. whether this object
	# or a parent has unbuildable subrefs)
	my $perl_ancestor = $self->{perl_filter} || $self->{perl_ancestor};

	return DBIx::StORM::OrderedRecordSet->_new({
		@_,
		filter           => $filter,
		parent           => $self,
		required_columns => $self->{required_columns},
		storm            => $self->_storm,
		table            => $self->_table,
		perl_ancestor    => $perl_ancestor,
		wheres           => [ @{ $self->{wheres}      }],
		sorts            => [ @{ $self->{sorts}       }],
		views            => { %{ $self->{views}       }},
		perl_wheres      => [ @{ $self->{perl_wheres} }],
		perl_sorts       => [ @{ $self->{perl_sorts}  }],
		perl_views       => { %{ $self->{perl_views}  }},
	});
}

=begin NaturalDocs

Method: view (instance)

  Create a <DBIx::StORM::RecordSetWithView> to represent a set of
  results from the database with computed columns

Parameters:

  %new_views - The view columns as hash with keys as a column name and
               values a code reference or string

Returns:

  An object of type <DBIx::StORM::OrderedRecordSet>

=end NaturalDocs

=cut

sub view {
	my $self = shift;
	my $new_views = { @_ };

	my $perl_ancestor = $self->{perl_filter} ||
		$self->{perl_ancestor};

	return DBIx::StORM::OrderedRecordSet->_new({
		@_,
		new_views        => $new_views,
		parent           => $self,
		required_columns => $self->{required_columns},
		storm            => $self->_storm,
		table            => $self->_table,
		perl_ancestor    => $perl_ancestor,
		wheres           => [ @{ $self->{wheres} }],
		sorts            => [ @{ $self->{sorts} }],
		views            => { %{ $self->{views} }},
		perl_wheres      => [ @{ $self->{perl_wheres} }],
		perl_sorts       => [ @{ $self->{perl_sorts} }],
		perl_views       => { %{ $self->{perl_views} }},
	});
}

=begin NaturalDocs

Method: lookup (instance)

  Fetch the first row from this RecordSet, and optionally fetch a
  particular field from it.

Parameters:

  $field - Optionally, the field to return from the first row

Returns:

  An object of type <DBIx::StORM::Record> if no field is supplied or the
  field is a foreign key, otherwise a simple scalar

=end NaturalDocs

=cut

sub lookup {
	my ($self, $field) = @_;

	if (($self->{perl_wheres} and @{ $self->{perl_wheres} }) or
	    ($self->{perl_sorts}  and @{ $self->{perl_sorts}  })) {
		# We can't limit this to one row, as maybe the Perl
		# filters will remove results.

		my $record = $self->[0];
		return unless $record;

		if ($field) {
			return $record->get($field);
		} else {
			return $record;
		}
	}

	# We can optimise this to do a one-row limit with some
	# databases

	# This could do with a tidy-up to avoid duplicating code

	my ($sth, $table_mapping) = $self->_get_sth({ limit => 1 });

	my $row = $sth->fetchrow_arrayref;

	# No result?
	return unless $row;

	if (not $table_mapping) {
		$table_mapping = $self->_table->_storm->_sqldriver->build_table_mapping($self->_table, $sth);
	}

	# If the connection has an inflation callback, call it now
	if (my @i = $self->_table->_storm->_inflaters) {
		foreach(@i) {
			$row = $_->inflate($self->_table->_storm, $row, $sth, $table_mapping);
		}
	}

	# And actually make the result
	my $result = $self->{last_result} = DBIx::StORM::Record->_new({
		table          => $self->_table,
		content        => $row,
		base_reference => $self->_table->name(),
		resultset      => $self,
		table_mapping  => $table_mapping
	});
        
	if ($field) {
		return $result->get($field);
	} else {
		return $result;
	}
}

=begin NaturalDocs

Method: _filter_id (private instance)

  Fetch a string uniquely identifying this filter

Parameters:

  None

Returns:

  String - The filter ID

=end NaturalDocs

=cut

sub _filter_id {
	return shift()->{filter_id};
}

=begin NaturalDocs

Method: _recommended_columns (private_instance)

  Fetch a list of recommended columns for this filter

Parameters:

  None

Returns:

  An array reference of strings representing the path of the
  recommended columns

=end NaturalDocs

=cut

sub _recommended_columns {
	my $self = shift;
	my $cols = $recommended_columns->{$self->_filter_id()};
	if ($cols) {
		DBIx::StORM->_debug(3, "recommended: " , join(", ", keys%$cols), "\n");
		return [ keys(%$cols) ];
	} else {
		DBIx::StORM->_debug(3, "No recommended columns\n");
		return undef;
	}
}

=begin NaturalDocs

Method: _recommend_column (private instance)

  Recommend a new column for this filter to pre-fetch in future

Parameters:

  String $column - The full path of the column to pre-fetch next time

Returns:

  Nothing

=end NaturalDocs

=cut

sub _recommend_column {
	my $self = shift;
	my $column = shift;

	DBIx::StORM->_debug(3, "recommend: $column\n");
	$recommended_columns->{$self->_filter_id()}->{$column} = 1;
}

=begin NaturalDocs

Method: _table (private instance)

  Fetch the table object underlying this RecordSet

Parameters:

  None

Returns:

  Object - An object of type <DBIx::StORM::Table>

=end NaturalDocs

=cut

sub _table {
	return shift()->{table};
}

=begin NaturalDocs

Method: _as_array (private instance)

  Actually do the query, and return a tied array that can be used to
  access the <DBIx::StORM::Record> objects. A tied array is used as it
  means a maximum of two result objects are kept in memory at once, but
  does mean you can't randomly access or otherwise tweak the array

Parameters:

  None

Returns:

  ArrayRef - An array reference tied to class <DBIx::StORM::RecordArray>

=end NaturalDocs

=cut

sub _as_array {
	my $self = shift;

	# If there are any perl filters, we can't use the tied version
	if (($self->{perl_wheres} and @{ $self->{perl_wheres} }) or
	    ($self->{perl_sorts } and @{ $self->{perl_sorts } }) or
	    ($self->{perl_views } and %{ $self->{perl_views } })) {
		return $self->array();
        }

	my ($sth, $table_mapping) = $self->_get_sth();

	my @result;
	tie @result, "DBIx::StORM::RecordArray", {
		resultset     => $self,
		table_mapping => $table_mapping,
		table         => $self->_table(),
		sth           => $sth,
		complete      => $self->_recommended_columns() ? 0 : 1
	};

	return \@result;
}

=begin NaturalDocs

Method: array (instance)

  Actually do the query, and return an array of <DBIx::StORM::Record>
  objects. Unlike the array dereference, this returns a proper perl
  array rather than a tied array. This means you can randomly access
  the results, but it also takes a lot of memory

Parameters:

  None

Returns:

  ArrayRef - An array of <DBIx::StORM::Record> Objects

=end NaturalDocs

=cut

sub array {
	my $self = shift;

	my ($sth, $table_mapping) = $self->_get_sth();

	my @result;

	while(my $row = $sth->fetchrow_arrayref) {
		next unless @$row;

		$row = [ @$row ]; # Copy

		$table_mapping ||=
			$self->{table}->_storm->_sqldriver->build_table_mapping($self->{table}, $sth);

		# If the connection has an inflation callback, call it now
		if (my @i = $self->{table}->_storm->_inflaters) {
			foreach(@i) {
				$row = $_->inflate($self->{table}->_storm, $row, $sth,
					$table_mapping);
			}
		}

		# And actually make the result
		push @result, DBIx::StORM::Record->_new({
			table          => $self->{table},
			content        => $row,
			base_reference => $self->{table}->name,
			resultset      => $self,
			table_mapping  => $table_mapping
		});
	}

	# Now apply the filters
	$self->{perl_wheres} ||= [ ];
	foreach my $where (@{ $self->{perl_wheres} }) {
		@result = grep { $where->() } @result;
	}

	$self->{perl_sorts} ||= [ ];
	foreach my $sort (@{ $self->{perl_sorts} }) {
		@result = sort $sort @result;
	}

	return \@result;
}

=begin NaturalDocs

Method: _get_sth (private instance)

  Execute the query and set up a DBI statement handle

Parameters:

  None

Returns:

  Object $sth - A DBI statement handle from which query results can be fetched
  HashRef $table_mapping - A mapping of column references to result indices

=end NaturalDocs

=cut

sub _get_sth {
	my $self = shift;
	my $extras = shift || { };

	# We can compile this filter, so let's go
	return $self->_storm->_sqldriver->do_query({
		%$extras,
	        required_columns    => $self->{required_columns},
	        recommended_columns => $self->{recommended_columns},
	        complete            =>
	                $self->_recommended_columns() ? 0 : 1,
	        table               => $self->{table},
	        wheres => @{ $self->{wheres} } ? $self->{wheres} : undef,
	        views  => %{ $self->{views } } ? $self->{views } : undef,
	        sorts  => @{ $self->{sorts } } ? $self->{sorts } : undef,
	});
}

=begin NaturalDocs

Method: _storm (private instance)

  Get the <DBIx::StORM> object this result set was created using

Parameters:

  None

Returns:

  Object - A <DBIx::StORM> object

=end NaturalDocs

=cut

sub _storm {
	my $self = shift;
	return $self->{storm};
}

sub _as_string {
	return overload::StrVal(shift());
}

sub update {
	my $self = shift;
	my $filter = shift;

	my $perl_filters = ($self->{perl_wheres} and @{ $self->{perl_wheres} });
	my $parsed = $self->_do_parse($filter, "UPDATE", binding => 1) unless $perl_filters;
	if ($parsed) {
		# We can compile this filter, so let's go
		return $self->_storm->_sqldriver->do_query({
	        	verb    => "UPDATE",
			updates => $parsed->[0],
		        table   => $self->{table},
		        wheres  => @{ $self->{wheres} } ? $self->{wheres} : undef,
		        views   => %{ $self->{views } } ? $self->{views } : undef,
		});
	} else {
		$self->_storm->_debug(1, "Failed to optimise update");
		my $row_count = 0;
		foreach my $obj (@$self) {
			local $_ = $obj;
			$obj->_autocommit(0);
			&$filter;
			$obj->_commit();
			$obj->_autocommit(1);
			++$row_count;
		}
		return $row_count;
	}
}

sub delete {
	my $self = shift;

	my $perl_filters = ($self->{perl_wheres} and @{ $self->{perl_wheres} });
	unless ($perl_filters) {
		# We can compile this filter, so let's go
		return $self->_storm->_sqldriver->do_query({
	        	verb    => "DELETE",
		        table   => $self->{table},
		        wheres  => @{ $self->{wheres} } ? $self->{wheres} : undef,
		});
	} else {
		$self->_storm->_debug(1, "Failed to optimise delete");
		my $row_count = 0;
		foreach my $obj (@$self) {
			$obj->delete;
			++$row_count;
		}
		return $row_count;
	}
}

sub _do_binding {
	my $self   = shift;
	my $filter = shift;
	my $parsed = shift;
	my $mode   = shift;

        if (uc($mode) ne "UPDATE") {
                die("Bad binding mode - only UPDATE supported (not $mode)");
        }

	my $lexmap = DBIx::StORM::LexBindings->lexmap($filter);

	my ($document, $xp) = @$parsed;
	foreach my $node($xp->findnodes('//perlVar')) {
		no strict "refs";
		my $var = $node->getAttribute("name");
		return undef unless $var =~ m/^\$(.+)/;
		my $p = $1;

		my $val;
		   if (defined($lexmap->{$p}))   { $val = $lexmap->{$p}   }
		elsif (defined($lexmap->{$var})) { $val = $lexmap->{$var} }
		else                             { $val = $$p }

		$node->setAttribute("value", $val);
	}

	return 1;
}

1;
__END__

=head1 NAME

DBIx::StORM::RecordSet

=head1 DESCRIPTION

This represents a set of results (rows) from the database. There are a
few methods here to manipulate the rows as a group, but conveniently a
RecordSet behaves like an array reference, so by doing so you can
foreach() over it or look up rows by index. You should not create
RecordSets directly, but instead obtain them from a
DBIx::StORM connection using the table methods.

=head2 METHODS

=head3 $instance->grep(sub { })

Filter the result set, returning a new RecordSet. The subroutine will
be called once for each row in the RecordSet with $_ set to the
DBIx::StORM::Record object. If the subroutine returns a true value the
Record will be added to the return RecordSet. $instance is not
modified.

=head3 $instance->lookup(field)

Return the value of I<field> from the first result in the set.
Shorthand for $instance->[0]->_get(I<field>)

=head3 $instance->update(sub { })

For each Record in the RecordSet, the subroutine is executed with $_
set to the Record. The subroutine is allowed to alter the fields of
$_, and the changes will be written back to the database.

=head3 $instance->delete()

The Records in the RecordSet will all be invalidated and then removed
from the database.

=head2 EXAMPLE

 foreach my $result (@$resultset) {
   print "In row ", $result->id, " the total price is ",
     $result->total, ".\n";
 }

=cut
