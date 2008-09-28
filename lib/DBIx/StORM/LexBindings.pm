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

use B qw(svref_2object comppadlist class SVf_IOK SVf_NOK SVf_POK cstring);

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
	elsif ($val->isa("B::RV") or
		# Oh god! Sometimes it seems that the RV isn't
		# described as an RV until you poke it
		($val->can("RV") and $val->RV and $val->RV->can("RV"))) {
		my $thingy = $val->RV;
		my $handled = ($] < 5.008); # don't attempt unless Perl >= v5.8.0
		if (not $handled and ref $thingy and $thingy->isa("B::PVMG")) {
			eval {
				my $obj = ${ $val->object_2svref };
				if ($obj->isa("DBIx::StORM::Record")) {
					push @$toreturn, $obj;
					$handled = 1;
				} else {
					die("Not a result, abort eval");
				}
			};
		}
		warn $@ if ($@ and $@ !~ m/Not a result/);
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
	my @names = $namesi->ARRAY;

	# Turn the list into a hash
	for(my $i = 1; $i < @names; $i++) {
		# The name should be a string (PV)
		if (class($names[$i]) =~ m/^PV/ and $names[$i]->FLAGS & SVf_POK) {
			# Extract the variable name
			my $name = (cstring($names[$i]->PV) =~ m/"(.*)"/)[0]
				or return;

			# Now get the value
			my $new_val = $class->b_to_item(($valsi->ARRAY)[$i]);
			if ($new_val) { $map->{$name} = $new_val->[0]; }
			else { return; }
		}
	}

	# All done
	return $map;
}

=begin NaturalDocs

Method: fetch_by_targ (public static)

  Return the value of a variable in scope in a given code ref where
  the targ parameter (index into the stash) is known. You can hand
  in a previously calculated stash array if preferred, to save the
  overhead of rebuilding it.

Parameters:

  CodeRef $codref - The code reference to inspect
  ArrayRef $valsi - The stash for the code-ref, or undef if not known
  Integer $targ   - The index into the stash of the desired element

Returns:

  ArrayRef - The stash for the code-ref
  Scalar   - The value for the given index as a perl scalar

=end NaturalDocs

=cut

sub fetch_by_targ {
	my ($class, $coderef, $valsi, $targ) = @_; 

	if (not $valsi) {
		(undef, $valsi) = svref_2object($coderef)->PADLIST->ARRAY;
	}

	my $value = DBIx::StORM::LexBindings->b_to_item(($valsi->ARRAY)[$targ]);

	return ($valsi, $value ? $value->[0] : undef);
}

1;
