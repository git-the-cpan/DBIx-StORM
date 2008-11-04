#!/usr/bin/perl

package DBIx::StORM::RecordSet;

use strict;
use warnings;

use overload '@{}' => "_as_array",
             '""' => "_as_string";

use Carp;
use Scalar::Util qw(blessed weaken);

use DBIx::StORM::FilteredRecordSet;
use DBIx::StORM::LexBindings;
use DBIx::StORM::OrderedRecordSet;
use DBIx::StORM::ParseCV;

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
  String $mode - The type of parse required for perl (eg. select, order)

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
	my $parsed;
	my $storm  = $self->_storm;

	# Compile the code if we haven't seen this sub before
	if (exists $$storm->{cache}->{filters}->{$mode}->{$filter}
		and $$storm->{cache}->{filters}->{$mode}->{$filter}->[0]) {
		$parsed = $$storm->{cache}->{filters}->{$mode}->{$filter};
	} else {
		$parsed = $self->_parse($filter, $mode);
		my $parse = [ $filter, $parsed ];
		weaken($parse->[0]);
		$$storm->{cache}->{filters}->{$mode}->{$filter} = $parse;
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
  String $mode - The type of parse required (eg. select, order)

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
		perl_wheres      => [ @{ $self->{perl_wheres} }],
		perl_sorts       => [ @{ $self->{perl_sorts}  }],
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
		perl_wheres      => [ @{ $self->{perl_wheres} }],
		perl_sorts       => [ @{ $self->{perl_sorts}  }],
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

  ArrayRef - An array reference tied to this class.

=end NaturalDocs

=cut

sub _as_array {
	my $self = shift;

	# If there are any perl filters, we can't use the tied version
	if (($self->{perl_wheres} and @{ $self->{perl_wheres} }) or
	    ($self->{perl_sorts } and @{ $self->{perl_sorts } })) {
		return $self->array();
        }

	($self->{sth}, $self->{table_mapping}) =
		$self->_get_sth();

	tie my @result, ref($self), $self;
	return \@result;
}

=begin NaturalDocs

Method: array (instance)

  Actually do the query, and return an array of <DBIx::StORM::Record>
  objects. Unlike the array dereference, this returns a proper perl
  array rather than a tied array. This means you can randomly access
  the results, but it also takes a lot of memory

  It also means you can't push() onto it to add more rows.

  This method is likely to go away when the fake array gets real
  enough to fool.

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
	my ($self, $filter, $parsed, $mode) = @_;

        if (uc($mode) ne "UPDATE") {
                die("Bad binding mode - only UPDATE supported (not $mode)");
        }

	my ($lexmap, $valsi);
	my ($document, $xp) = @$parsed;
	foreach my $node($xp->findnodes('//*[@targ]')) {
		my $targ = $node->getAttribute("targ");
		next unless "$targ" > 0;
		($valsi, my $val) = DBIx::StORM::LexBindings->fetch_by_targ(
			$filter, $valsi, $targ
		);
		$node->setAttribute("value", $val);
	}
	foreach my $node($xp->findnodes('//perlVar[not(@targ)]')) {
		$lexmap ||= DBIx::StORM::LexBindings->lexmap($filter);
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

sub TIEARRAY {
	my $class = shift;
	my $self  = shift;
	
	$self->{pointer} ||= 0;

	return $self;
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
	if ($self->{pointer} - 1 != $index and $self->{pointer} != $index) {
		die("Out of order Record array access not permitted");
	}

	# If foreach wants the previous result, we can skip a whole load
	# of effort as we cached it.
	if ($self->{pointer} - 1 == $index) { return $self->{last_result}; }

	# Increment our expectation of the next index we're expecting
	$self->{pointer}++;

	# Get the data for the row and clone it so it can be modified.
	return undef if ($self->{sth}->rows == 0);
	my $row = [ $self->{sth}->fetchrow_array ];

	# We should have got a row - otherwise we've run off the end of the
	# "array"
	if (not @$row) { return undef; }

	# We may need to build a table mapping if this is the first result in
	# the RecordSet
	if (not $self->{table_mapping}) {
		$self->{table_mapping} = $self->_table->_storm->_sqldriver->build_table_mapping($self->{table}, $self->{sth});
	}

	# If the connection has an inflation callback, call it now
	if (my @i = $self->_table->_storm->_inflaters) {
		foreach(@i) {
			$row = $_->inflate($self->_table->_storm, $row, $self->{sth},
				$self->{table_mapping});
		}
	}

	# And actually make the result
	return $self->{last_result} = DBIx::StORM::Record->_new({
		table          => $self->_table,
		content        => $row,
		base_reference => $self->_table->name(),
		resultset      => $self,
		table_mapping  => $self->{table_mapping}
	});
}

sub FETCHSIZE {
	return shift()->{sth}->rows;
}

foreach my $method (qw(STORE STORESIZE PUSH POP SHIFT UNSHIFT SPLICE DELETE EXISTS)) {
	no strict "refs";
	*$method = sub { croak("cannot $method a RecordSet"); }
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
