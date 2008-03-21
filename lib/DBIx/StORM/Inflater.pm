#!/usr/bin/perl

package DBIx::StORM::Inflater;

=begin NaturalDocs

Class: DBIx::StORM::Inflater

An abstract class for developing inflaters/deflaters. An inflater gets access
to the data before it is converted into a record, so it can tweak the data
in some way. A deflater performs the opposite, so that inflated values can
be saved. The archetypal use-case is something that converts SQL date values
into objects of one's preferred date class.

There is one class that handles both inflation and deflation, and it ought
to be able to round-trip data. 

=end NaturalDocs

=cut

use strict;
use warnings;

=begin NaturalDocs

Method: inflate (public instance)

  Take a row of data from the database and turn it into an in-memory
  representation of the row to work with.

  The important thing here is the $table_mapping. It consists of an array
  of strings, where each string specifies a table name/field name
  specification. Table information is included as one select may select
  from more than one table (where foreign keys are involved).

  A typical value may be "variety->fruit_id->name" which specifies that
  starting from the table "variety", a look-up was made via the "fruit_id"
  column into another table, from which the field "name" has been loaded.
  It is stored in $values at the same array index as this string is in
  $table_mapping.

  Values may have as few as one "->" if they come from the "base" table of
  the query, or may be nested deeply.

Parameters:

  Object $storm - The DBIx::StORM object this query came from
  ArrayRef $values - The values fetched from the database
  Object $sth - The DBI statement handle for the row fetched
  ArrayRef $table_mapping - Table information as described above

Returns:

  ArrayRef - The inflated equivilent of $values, to be used in the object

=end NaturalDocs

=cut

sub inflate {
	my ($self, $storm, $values, $sth, $table_mapping) = @_;
	return $values;
}

=begin NaturalDocs

Method: deflate (public instance)

  Deflate a given set of values for a record into database format.

Parameters:

  Object $storm - The DBIx::StORM object this query came from
  ArrayRef $values - The array of values to be inserted, as described in the
                     documentation for insert.
  ArrayRef $table_mapping - A table mapping of columns, as described in the
                            documentation for insert. Like insert, the deflater
                            may be processing values for several related tables
                            at once.

Returns:

  ArrayRef - The deflated equivilent of $values

=end NaturalDocs

=cut

sub deflate {
	my ($self, $storm, $values, $table_mapping) = @_;
	return $values;
}

1;
__END__

=head1 NAME

DBIx::StORM::Inflater - An abstract base class for inflaters

=head1 DESCRIPTION

This is an abstract base class for inflaters/deflaters and cannot be
instantiated directly.

=head1 SEE ALSO

  L<DBIx::StORM>
  L<DBIx::StORM::Record>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.nameE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
