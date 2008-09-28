#!/usr/bin/perl

package DBIx::StORM::Record;

=begin NaturalDocs

Class: DBIx::StORM::Record

A StORM class representing an individual row from the database.

This is essentially a wrapper for a result from a DBI statement handle.
It appears to be a hash reference, where the keys of the hash are
the column names in the result and the hash values are the column
values.

=end NaturalDocs

=cut

use strict;
use warnings;

use overload '""'     => "_as_string",
             '%{}'    => "_as_tied_hash",
             'bool'   => "_as_bool",
             fallback => 1
;

use Scalar::Util qw(blessed);

use DBIx::StORM::TiedCallback;

=begin NaturalDocs

Method: _new (private instance)

  Create a new DBIx::StORM::Record object from the RecordSet. The Record
  may cover data from a lot of tables as it may have information for
  tables accessed as foreign keys. Therefore a result has a concept of
  "base reference" which is the access path to this result, which is used
  to index into the map of columns.

Parameters:

  HashRef $params - Parameters to build the Record

Returns:

  Object - A new DBIx::StORM::Record object

=end NaturalDocs

=cut

sub _new {
	my ($class, $params) = @_;
	my $self = {
		%$params,
		commit      => 0,   # In auto-commit mode?
		outstanding => { }, # Columns we haven't written back
		cache_fk    => { }, # The foreign key cache
	};

	# If we have content then this Record comes from a table,
	# if not it's a new result we're planning to inset
	if ($self->{content}) {
		$self->{in_table} = 1; # Is in a table
		$self->{commit}   = 1; # Auto commit changes
	} else {
		$self->{content}        = []; # No content
		$self->{table_mapping}  = {}; # No table mapping
		$self->{in_table}       = 0;  # Not in a table
	}

	# Because this is a hash-overloaded object we can't directly
	# dereference it to get to our private data, so we make the
	# object a scalar reference to a hash reference
	# $object->{key} gets the column value
	# $$object->{key} gets the private data
	my $self2 = \$self; # Loathe overloading dereferencing

	# This hack is used for the class interface
	if ($self->{table}->{bless_map} and
	    my $pkg = $self->{table}->{bless_map}->{$self->{table}->name}) {
		bless $self2 => $pkg;
		$self2->_init;
		return $self2;
	} else {
		# It's a normal Record, phew!
		return bless $self2, $class;
	}
}

=begin NaturalDocs

Method: _as_tied_hash (private instance)

  Used by overloading to provide hash-reference access. The keys
  of this hash are the columns in the result (for this table only)
  and the values are the column values.

Parameters:

  None

Returns:

  HashRef - A tied hash of the column information

=end NaturalDocs

=cut

sub _as_tied_hash {
	my $self = shift;

	# Don't have lots of objects floating round - they get
	# out of sync!
	return $$self->{tied} if $$self->{tied};

	# Make a hash, tie it and return it
	my %hash;
	tie %hash, "DBIx::StORM::Record", $self;
	return $$self->{tied} = \%hash;
}

=begin NaturalDocs

Method: get (public instance)

  Fetch a field from the Record. The field is returned as an l-value,
  so you can assign to it. This is for people who don't like the
  hash-reference style access.

Parameters:

  $field - The field to fetch from the row

Returns:

  Tied scalar as an l-value - The scalar may be a reference, and is tied to
  class <DBIx::StORM::TiedCallback>

=end NaturalDocs

=cut

sub get : lvalue {
	my ($self, $field) = @_;
	# What we will return

	my @result = $self->_build_column_information_for_get($field);
	return undef unless @result;

	if (ref $result[0]) {
		# We have a foreign key column
		$result[0];
	} else {
		# Else we have a simple value result, tie it
		my $resresult;
		my @column_info = $self->_build_column_information_for_get($field);
		tie $resresult, "DBIx::StORM::TiedCallback",
			fetch => sub {
				return $self->_get_simple_value(@column_info);
			},
			store => sub {
				my $tie_object = shift;
				my $newval = shift;

				$self->_update_field($column_info[0], $newval);
				return $newval;
			};
		$resresult;
	}
}

=begin NaturalDocs

Method: _get_simple_value (private instance)

  Fetch the scalar value of a "simple" (ie. not foreign key) column. This
  is used by TiedCallback.

Parameters:

  $field - The qualified field to fetch
  $raw_field - The string field name

Returns:

  Scalar - the column value, or undef on failure

=end NaturalDocs

=cut

sub _get_simple_value {
	my $self = shift;
	my $field = shift;
	my $raw_field = shift;

	return undef unless ($field or $raw_field);

        if (defined $raw_field and defined $$self->{outstanding}->{$raw_field}) {
		return $$self->{outstanding}->{$raw_field};
        } elsif (defined $$self->{table_mapping}->{$field}) {
		my $value = $$self->{content}->[$$self->{table_mapping}->{$field}];

		# Allow per-field inflation
		foreach my $i ($$self->{table}->_storm->_inflaters) {
			$i->inflate_field($self, $$self->{content}, $$self->{table_mapping}, \$value, $field);
		}

		return $value;
	} else {
		return undef; # Field doesn't exist
	}
}

=begin NaturalDocs

Method: _build_column_information_for_get (private instance)

  Turn a string column name into a fully qualified content path, and also
  check to see if it's a foreign key lookup and fetch the result if so.

Parameters:

  $field - The string column name to fetch

Returns:

  Variable - undef on failure, one DBIx::StORM::Record on a foreign key
             lookup or a ($field, $raw_field) pair suitable for feeding to
             _get_simple_value for non-foreign columns.

=end NaturalDocs

=cut

sub _build_column_information_for_get {
	my ($self, $field) = @_;

	# This object must not be deleted
	$self->_not_invalid();

	# Build the access path of the field
	my $lookup_field = $$self->{base_reference} . "->$field";

	# Load foreign key information
	$$self->{foreign_keys} ||= $$self->{table}->foreign_keys();

	# In future, pre-load this column
	$$self->{resultset}->_recommend_column($lookup_field);

	# If the column isn't loaded then load the entire row
	if (not $$self->{complete} and
	    not exists $$self->{table_mapping}->{$lookup_field}) {
		$self->refresh(1) if $$self->{in_table};
	}

	# If this is a foreign key column we need to instantiate the result
	# object instead of just a plain value
	if ($$self->{foreign_keys} and
	    my $fk = $$self->{foreign_keys}->{$field}) {
		DBIx::StORM->_debug(3, "doing FK lookup on " . $$self->{table}->name() . "\n");

		# Have we already loaded this particular field?
		if ($$self->{cache_fk}->{$lookup_field}) {
			return ($$self->{cache_fk}->{$lookup_field}, $lookup_field);
		} else {

			# OK, lets get the foreign key value from the content
			# of this result
			die("bad foreign key: $fk") unless
				($fk =~ m/^(.*)->(.*)$/);
			my $column = $2;
			my $value = defined(
				$$self->{table_mapping}->{$lookup_field}) ?
				$$self->{content}->[$$self->{table_mapping}->{$lookup_field}] :
				undef;

			# Hopefully the value exists, otherwise we have a				# problem
			if (not defined $value) {
				# If not defined but the row is new, we want
				# to allow you to assign to it. We therefore
				# treat it as a simple value. I'd like to make
				# this auto-vifify a Record, but is this
				# the right behaviour, or should you assign
				# it explicitly? It makes writing back
				# the information more challenging :-)
				return ($lookup_field, $field);
			}

			# We have a value, fetch the record
			my $new_table = $$self->{table}->_storm->{$1};
			if (my $bless_map = $$self->{table}->{bless_map}) {
				$new_table->{bless_map} = $bless_map;
			}
			my $resresult = $new_table->_get_record_for_fk(
				$column, $value, $$self->{resultset},
				$$self->{base_reference} . "->$field",
				$$self->{table_mapping}, $$self->{content});

			# And cache it
			$$self->{cache_fk}->{$lookup_field} = $resresult;
			return ($resresult, $lookup_field);
		}
	} else {
		# It's a simple value, so make an assignable thingy
		return ($lookup_field, $field);
	}
}

=begin NaturalDocs

Method: _as_string (private instance)

  A string representation of the Record, used for overloading. We stringify
  to the primary key where possible. This may sound perverse, but it means
  that

    print $result->{foreign_key};

  gives you the foreign key value as you'd expect. It also makes for a
  reasonable serialisation. If there is no primary key we serialise in the
  standard Perl fashion.

Parameters:

  None

Returns:

  String - a printable value for this result

=end NaturalDocs

=cut

sub _as_string {
	my $self = shift;

	# A deleted row would be bad here
	$self->_not_invalid();

	# Can we serialise as a primary key?
	if (defined($$self->{table})
		and my $pk = $$self->{table}->primary_key()) {

		# Our intention is to join together the PK values with commas
		my @ret;
		foreach my $p (@$pk) {
			my $copy_p = $p;
			$p =~ s/.*->(.*)/$$self->{base_reference} . "->$1"/e;
			my $ret = $self->_get_simple_value($p, $1);
			return overload::StrVal($self) if not defined $ret;
			push @ret, $ret;
		}
		return overload::StrVal($self) unless @ret;
		return join ",", @ret;
	}

	# No PK, so do things the standard perl way
	return overload::StrVal($self);
}

=begin NaturalDocs

Method: autocommit (public instance)

  Whether to write changed rows back to the database as soon as possible.
  This is my default true for rows loaded from a table, and false before
  a new row is inserted.

  Auto committing can thrash the database with small queries if you make
  a lot of updates to a row quickly, so turning off autocommit will allow
  those changes to be written back with one query.

Parameters:

  None

Returns:

  Nothing

=end NaturalDocs

=cut

sub autocommit : lvalue {
	my ($self, $newval) = @_;

	$self->_not_invalid;
	if (defined $newval) {
		$self->commit;
		$$self->{commit} = shift;
	} else {
		tie my $callback, "DBIx::StORM::TiedCallback",
			fetch => sub {
				return $$self->{commit};
			},
			store => sub {
				$self->commit;
				$$self->{commit} = shift @_;
			};
		return $callback;
	}
}

sub _not_invalid {
	my $self = shift;
	if ($$self->{invalid}) { confess("Cannot call this method on an invalid (deleted) result."); }
}

sub _as_bool {
	my $self = shift;
	return not $$self->{invalid};
}

sub delete {
	my $self = shift;

	# Find out how to describe this row in the database
	my($wheres, $pks) = $$self->{table}->_build_result_identity($self);

	# Actually ask the SQLDriver to do the deletion
	my ($sth, $table_mapping) =
		$$self->{table}->_storm->_sqldriver->do_query({
			table                 => $$self->{table},
			wheres                => $wheres,
			verb                  => "DELETE",
			record_base_reference => $$self->{base_reference}
	});

	# And finally mark this object as broken.
	$$self->{invalid} = 1;
}

sub commit {
	my $self = shift;
	my $iquote = $$self->{table}->_storm->_sqldriver->_identifier_quote;
	$self->_not_invalid();

	if ($$self->{in_table}) {
		my @fragments;
		my @mapping;
		while(my($field,$value) = each %{ $$self->{outstanding} }) {
			$field =~ s/.*->//;
			# If a foreign key was set, then flatten it now
			if (ref $value and blessed $value and $value->isa("DBIx::StORM::Record")) {
				$value->commit;
				$value = "" . $value;
			}

			# Add this SQL fragment
			push @fragments, [ "$iquote$field$iquote = ?", $value ];
			push @mapping, $$self->{table}->name . "->" . $field;
		}
		return unless @fragments; # Any fields to update

	        my($wheres, $pks) = $$self->{table}->_build_result_identity(
			$self
		);

        	my ($sth, $table_mapping) = $$self->{table}->_storm->_sqldriver->do_query({
			table => $$self->{table},
	                wheres => $wheres,
			updates => \@fragments,
			verb => "UPDATE",
			record_base_reference => $$self->{base_reference},
			mapping => \@mapping
	        });

		$$self->{outstanding} = { };

	} else {

		# If a foreign key was set, then flatten it now
		while(my($field,$value) = each %{ $$self->{outstanding} }) {
			if (ref $value and blessed $value and $value->isa("DBIx::StORM::Record")) {
				$value->commit;
				$$self->{outstanding}->{$field} = "" . $value;
			}
		}

		my ($pk_map) = $$self->{table}->_storm->_sqldriver()->do_insert(
			table   => $$self->{table},
			content => $$self->{outstanding}
		);

		$$self->{outstanding} = { };
		$$self->{in_table} = 1;

		if ($pk_map) {
			while(my($pk, $pk_val) = each(%$pk_map)) {
				DBIx::StORM->_debug(3, "Updating PK field $pk = $pk_val");
				$self->_update_field($pk, $pk_val);
			}
			$self->refresh(1);
			return 1;
		} else {
			return 1;
		}
	}
}

sub refresh {
	my $self = shift;
	my $full = shift;
	$self->_not_invalid();

	$$self->{table}->_rebuild_record($self, $full);
}

sub _update_content {
	my $self = shift;
	$$self->{content} = shift;
	$$self->{table_mapping} = shift;
}

sub _fields {
	my $self = shift;
	$self->_not_invalid();

	if (not $$self->{complete}) {
		$self->refresh(1);
	}
	my $br = $$self->{base_reference};

	return map { 
		if (m/^$br->(.*)/) {
			my $f = $1;
			if ($f !~ m/->/) {
				$f
			} else {
				();
			}
		}
	} keys %{ $$self->{table_mapping} };
}

sub _update_field {
	my $self = shift;
	my $field = shift;
	my $newval = shift;

	my $newval_is_record = eval {
		ref $newval and blessed $newval and $newval->isa("DBIx::StORM::Record")
	};

	if ($newval_is_record) {
		# We need to sniff the foreign keys and work out what the
		# target value is, as it may not necessarily be the primary
		# key.

		my $fks = $$self->{table}->foreign_keys;
		my (undef, $part_field) = $field =~ m/(.*?)->(.*)/;
		if ($fks->{$part_field}) {
			$fks->{$part_field} =~ m/(.*?)->(.*)/;
			my ($table, $rfield) = ($1, $2);

			# Is the new record from the correct table?
			if ($rfield and $$newval->{table}->name eq $table) {
				# Assign over the remote field
				$newval = $newval->{$rfield};
			} else {
				# Stringify and hope for the best!
				$newval = "" . $newval;
			}
		} else {
			# Stringify and hope for the best!
			$newval = "" . $newval;
		}
	} else {
		# Allow per-field inflation
		foreach my $i ($$self->{table}->_storm->_inflaters) {
			$i->deflate_field($self, $$self->{content}, $$self->{table_mapping}, \$newval, $field);
		}
	}

	if (defined(my $id = $$self->{table_mapping}->{$field})) {
		$$self->{content}->[$id] = $newval;
		$self->updated($field => $newval);
		# We may need to also empty the foreign key cache
		delete $$self->{cache_fk}->{$field};
		DBIx::StORM->_debug(3, "Old _update_field: ". $field. "=$newval\n");
	} else {
		my $id = @{ $$self->{content} };
		$$self->{content}->[$id] = $newval;
		$$self->{table_mapping}->{$field} = $id;
		$self->updated($field => $newval);
		DBIx::StORM->_debug(3, "New _update_field: ". $field. "=$newval\n");
	}
}

=begin NaturalDocs

Method: associated (public instance)

  Find Records in another table that have a foreign key that links back
  to this record.

Parameters:

  String $table - Table to scan for links back to this record

Returns:

  Object - A DBIx::StORM::RecordSet of records with a column that match

=end NaturalDocs

=cut

sub associated {
	my ($self, $target_name) = @_;

	my $target_table = $$self->{table}->_storm->get($target_name);

	my $fks = $$self->{table}->_storm->_sqldriver->foreign_keys(
		$target_table
	);

	my $looking_for = "^" . quotemeta($$self->{table}->name) . "->";

	my @possible_wheres;
	my @bind_values;
	my $iquote = $$self->{table}->_storm->_sqldriver->_identifier_quote;
	while(my($col_from, $col_to) = each %$fks) {
		if ($col_to =~ s/$looking_for//) {
			# $copy now contains the column name
			push @possible_wheres, "$iquote$col_from$iquote = ?";
			push @bind_values, $self->{$col_to};
		}
	}

	DBIx::StORM->_debug(3, "Looking at " . $target_table->name .
		" for @possible_wheres (values @bind_values).\n");

	my $rs = DBIx::StORM::FilteredRecordSet->_new({
                filter           => [
			join(" OR ", @possible_wheres),
			@bind_values
		],
		pre_parsed       => 1,
                parent           => $target_table,
                table            => $target_table,
                required_columns => [ @{ $target_table->primary_key } ],
                storm            => $target_table->_storm,
                wheres           => [ ],
                sorts            => [ ],
                perl_wheres      => [ ],
                perl_sorts       => [ ],
        });
}

=begin NaturalDocs

Method: updated (public instance)

  Marks a field as having been changed, which will either push the
  field onto the list of fields that need to be written back or will
  trigger an immediate write to the database if autocommit is set.

  This allows the user to mark a field as changed where the change
  is made to an inner part of a data structure (as in this case no
  STORE() occurs on the outer data structure, so we don't even know
  that it is happening.

Parameters:

  String $field - The field that has just been changed.
  Scalar $new_value - Optionally, the new value that has just been assigned.
                      This is intended for internal use to save the overhead
                      of fetching the new value using get().

Returns:

  Nothing

=end NaturalDocs

=cut

sub updated {
	my ($self, $field, $new_value) = @_;

	# Fetch the new value if needbe
	if (not exists $$self->{outstanding}->{$field}) {
		$new_value = $self->get($field)
			if not defined $new_value;
		$$self->{outstanding}->{$field} = $new_value;
	}

	# Actually save to DB if autocommit is turned on
	$self->commit if ($$self->{commit});
}

sub TIEHASH {
	my ($class, $self) = @_;
	return $self;
}

sub FETCH {
	my ($self, $index) = @_;

	my @result = $self->_build_column_information_for_get($index);
	return undef unless @result;

	if (ref $result[0]) {
		# We have a foreign key column
		$result[0];
	} else {
		return $self->_get_simple_value(@result);
	}
}

sub STORE {
	my ($self, $index, $newval) = @_;

	my @col = $self->_build_column_information_for_get($index);
	die("Cannot update this field: $index") unless @col;

	if (ref $col[0]) {
		# We're updating a foreign key columnn
		$self->_update_field($col[1], $newval);
	} else {
		# We're updating a simple value
		$self->_update_field($col[0], $newval);
	}
	$self->commit if ($$self->{commit});

	return $self;
}

sub EXISTS {
	my ($self, $index) = @_;
	return defined($self->FETCH($index));
}

sub FIRSTKEY {
	my $self = shift;
	$self->{fields} ||=
		{ map { $_ => 1} $self->_fields };

	# Reset iterator
	keys %{ $self->{fields} };
	return $self->NEXTKEY;
}

sub NEXTKEY {
	my $self = shift;
	my $next = each %{ $self->{fields} };
	return ($next, $self->FETCH($next));
}

sub SCALAR {
	my $self = shift;
	return $self;
}

1;
__END__

=head1 NAME

DBIx::StORM::Record

=head1 DESCRIPTION

A row from the database. You can treat it has a hash reference to access
the column information.

You should not create a Record directly - either access one from a
RecordSet (by using array dereferencing) or use the insert() method on
the table to add a new row.

=head2 METHODS

=head3 $instance->get(I<$field>)

Look up the value for column I<$field> in the row. You can assign to the
field as well to update the value.

=head3 $instance->{I<$field>}

Shorthand for $instance->get(I<$field>)

=head3 $instance->delete()

Remove this Result from the database immediately. After this you cannot
make any further calls on the object (although one day you may be
allowed to re-insert it into the database).

=head3 $instance->refresh()

Update the object by re-loading the row from the database.

=head3 $instance->updated(I<$field>)

In certain circumstances (typically where a field has been inflated
into a data structure) the Record may not always recognise that a field
has been modified. This call is provided to allow you to mark a field
as having been changed, so that StORM will arrange to save it at
the appropriate moment.

=cut
