#!/usr/bin/perl

package DBIx::StORM::LexBindings;

=begin NaturalDocs

Class: DBIx::StORM::LexBindings

Build a hash map of lexical variables used in a code reference. The main
access point is the class method lexmap().

=end NaturalDocs

=cut

use strict;
use warnings;

use B qw(svref_2object comppadlist class SVf_IOK SVf_NOK SVf_POK);
use B::Concise();

=begin NaturalDocs

Method: b_to_item (private static)

  Turn a variable value from its B::* module objects into a real perl
  value. This may act recursively (for references, hashes and arrays).

Parameters:

  List - objects of B::* class

Returns:

  ArrayRef - The objects as their native Perl values

=end NaturalDocs

=cut

sub b_to_item {
	my $class = shift;
	my $toreturn = [ ];

	# Iterate through each value
	foreach my $val (@_) {

	DBIx::StORM->_debug(3,"In b_to_item with a $val\n");

	# What type is $val?
	if ($val->isa("B::AV")) {
		# It's an array (AV)
		my $ret = $class->b_to_item($val->ARRAY);
		if ($ret) { push @$toreturn, [ $ret ] } else { return; }
	}
	elsif ($val->isa("B::HV")) {
		# It's an hash (HV)
		my $ret = $class->b_to_item($val->ARRAY);
		if ($ret) { push @$toreturn, { @$ret } } else { return; }
	}
	elsif ($val->FLAGS & SVf_IOK) { push @$toreturn, $val->int_value; }
	elsif ($val->FLAGS & SVf_NOK) { push @$toreturn, $val->NV; }
	elsif ($val->FLAGS & SVf_POK) { push @$toreturn, $val->PV; }
	elsif ($val->isa("B::RV")) {
		my $thingy = $val->RV;
		my $handled = 0;
		if (ref $thingy and $thingy->isa("B::PVMG")) {
			eval {
				my $obj = ${ $val->object_2svref };
				if ($obj->isa("DBIx::StORM::Record")) {
					push @$toreturn, $obj;
					$handled = 1;
				} else {
					die("Not a result ($@), abort eval");
				}
			};
		}
		warn $@ if $@;
		if (not $handled) {
			push @$toreturn, $val->RV;
		}
	}
	elsif ($val->isa("B::PVNV")) {
		# May be a DBIx::StORM thingy
		eval {
			my $obj = ${ $val->object_2svref };
			if ($obj->isa("DBIx::StORM::Record")) {
				push @$toreturn, $obj;
			} else {
				die("Not a result ($@), abort eval");
			}
		};
		return if $@; # Obviously wasn't
	}
	else { return; }

	} # end foreach

	return $toreturn;
}

=begin NaturalDocs

Method: lexmap (public static)

  Build a hashmap of lexical variables used in a coderef. The hash
  returned has variables names as the keys, and the variable values
  as the corresponding hash value.

Parameters:

  CodeRef $codref - The code reference to inspect

Returns:

  HashRef - The lexical variables used in the coderef

=end NaturalDocs

=cut

sub lexmap {
	my ($class, $coderef) = @_;

	# $map will contain the lexicals
	my $map = { };

	# Extract the name and value arrays from the coderef
	my ($namesi, $valsi) = svref_2object($coderef)->PADLIST->ARRAY;

	# Un-B the names and values
	my ($names, $vals) =
		([ map { my $info = { };
			B::Concise::concise_sv($_, $info); $info }
			$namesi->ARRAY ], [ $valsi->ARRAY ]);

	# Turn the list into a hash
	for(my $i = 1; $i < @$names; $i++) {
		# The name should be a string (PV)
		if ($names->[$i]->{svclass} =~ m/^PV/) {
			# Extract the variable name
			my $name = ($names->[$i]->{svval} =~ m/"(.*)"/)[0]
				or return;

			# Now get the value
			my $new_val = $class->b_to_item($vals->[$i]);
			if ($new_val) { $map->{$name} = $new_val->[0]; }
			else { return; }
		}
	}

	# All done
	return $map;
}

1;
