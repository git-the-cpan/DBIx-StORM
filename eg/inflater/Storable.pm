#!/usr/bin/perl

package DBIx::StORM::Inflater::Storable;

use strict;
use warnings;

use base "DBIx::StORM::Inflater";

use Storable qw(nfreeze thaw);

sub new {
	my $class = shift;
	return bless { } => $class;
}

sub freeze {
	my ($self, $columnSpec) = @_;
	$self->{freeze}->{$columnSpec} = 1;
}

sub inflate {
	my ($self, $storm, $values, $sth, $table_mapping) = @_;

	# Copy over the values for this query
	my @return = @$values;

        # Reverse the table mapping
	my @reverse_tm;
	while(my($tableref, $index) = each %$table_mapping) {
		$reverse_tm[$index] = $tableref;
	}

	for(my $i = 0; $i < @return; ++$i) {
		my $tm = $reverse_tm[$i];

		if ($self->{freeze}->{$tm}) {
			$return[$i] = thaw($return[$i]);
		}
	}

	return \@return;
}

sub deflate {
	my ($self, $storm, $values, $table_mapping) = @_;

	# Copy over the values for this query
	my @return = @$values;

	for(my $i = 0; $i < @return; ++$i) {
		my $tm = $table_mapping->[$i];

		if ($self->{freeze}->{$tm}) {
			$return[$i] = nfreeze($return[$i]);
		}
	}

	return \@return;
}

1;
