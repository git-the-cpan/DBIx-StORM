#!/usr/bin/perl

use strict;
use warnings;

use DBIx::StORM;

# Disable debug
$DBIx::StORM::DEBUG = 0;

my @params = @ARGV;

# Set default params if none specified
if (not @params) {
	@params = ("dbi:DBM:");
}

my $connection = DBIx::StORM->connect(@params)
	or die("Cannot connect to database (DSN=$params[0])");

while(my($table_name, $table_object) = each %$connection) {
	# Print header
	print $table_name, "\n", "-" x length($table_name), "\n";

	# Walk the table
	my $row_counter = 0;
	foreach my $row (@$table_object) {
		# $row will be a primary key representation
		no warnings;
		print "Row ", ++$row_counter, ": $row\n";

		# And walk the columns
		foreach my $column_name (sort keys %$row) {
			my $column_value = $row->{$column_name};

			# $column_value could be an object so flatten
			# it.
			my $column_value_string = "" . $column_value;
			print "$column_name=$column_value_string";

			# Is it a foreign key?
			if (ref $column_value) {
				print " (FK)";
			}

			print "\n";
		}
	}

	print "\n";
}


__END__

=head1 NAME

walk_database.pl - Iterate over all tables and rows on a database
connection.

=head1 DESCRIPTION

This is a sample script provided with DBIx::StORM, to demonstrate how
to use the objects to list table contents.

It walks through all the tables available on a handle, and for each of
them prints the contents of the table. Note that on some databases this
can be an expensive operation.

=head2 USAGE

walk_database.pl [ dsnString username password ]

=head3 dsnString

Specifies a DSN to pass to the connect method.

=head3 username

Specifies a username to connect to the database as.

=head3 password

Specifies a password to connect to the database using.

=head1 SEE ALSO

  L<DBIx::StORM>
  L<DBIx::StORM::Table>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.nameE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Luke Ross

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
