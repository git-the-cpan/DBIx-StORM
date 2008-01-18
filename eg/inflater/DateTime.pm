#!/usr/bin/perl

package DBIx::StORM::Inflater::DateTime;

use strict;
use warnings;

use base "DBIx::StORM::Inflater";

use DateTime;

our %FORMATTERS = (
	mysql => "DateTime::Format::MySQL",
	Pg    => "DateTime::Format::Pg"
);

sub new {
	my $class = shift;
	my $self = { };
	
	while(my($dbd, $module) = each %FORMATTERS) {
		eval "use $module";
		$self->{"format_$dbd"} = $@ ? undef : $module;
	}

	return bless $self => $class;
}

sub inflate {
	my ($self, $storm, $values, $sth, $table_mapping) = @_;

	# Can we handle this type of database?
	my $database_type = $storm->dbi->{Driver}->{Name};
	return $values unless $self->{"format_$database_type"};

	# Copy over the values for this query
	my @return = @$values;

	my $formatter = $self->{"format_$database_type"};

	# Reverse the table mapping for type caching
	my @reverse_tm;
	while(my($tableref, $index) = each %$table_mapping) {
		$reverse_tm[$index] = $tableref;
	}

	my $type_map = $sth->{TYPE};
	return $values unless $type_map;
	for(my $i = 0; $i < @$type_map; ++$i) {
		if ($type_map->[$i] == 9) {
			# We have a date
			if ($formatter->can("parse_date")) {
				$return[$i] =
					$formatter->parse_date($return[$i]);
			}
		}
		if ($type_map->[$i] == 10) {
			# We have a time
			if ($formatter->can("parse_time")) {
				$return[$i] =
					$formatter->parse_time($return[$i]);
			} elsif ($formatter->can("parse_datetime")) {
				$return[$i] =
					$formatter->parse_datetime($return[$i]);
			}
		}
		if ($type_map->[$i] == 11) {
			# We have a timestamp
			if ($formatter->can("parse_timestamp")) {
				$return[$i] =
					$formatter->parse_timestamp($return[$i]);
			}
		}

		# And cache the type information for later
		$self->{typecache}->{overload::StrVal($storm)}->{$reverse_tm[$i]} = $type_map->[$i];
	}

	return \@return;
}

sub deflate {
	my ($self, $storm, $values, $table_mapping) = @_;

	# Can we handle this type of database?
	my $database_type = $storm->dbi->{Driver}->{Name};
	return $values unless $self->{"format_$database_type"};

	# Copy over the values for this query
	my @return = @$values;

	my $formatter = $self->{"format_$database_type"};

	for(my $i = 0; $i < @return; ++$i) {
		my $value = $return[$i];
		if (ref $value and $value->isa("DateTime")) {
			my $cached_type = $self->{typecache}->{overload::StrVal($storm)}->{$table_mapping->[$i]};
			$cached_type ||= 0; # Unknown

			if ($cached_type == 9) {
				$return[$i] = $formatter->format_date($value)
					if ($formatter->can("format_date"));
			} elsif ($cached_type == 10) {
				$return[$i] = $formatter->format_time($value)
					if ($formatter->can("format_time"));
			} elsif ($cached_type == 10) {
				$return[$i] = $formatter->format_timestamp($value)
					if ($formatter->can("format_timestamp"));
			} else {
				$return[$i] = $formatter->format_datetime($value)
					if ($formatter->can("format_datetime"));
			}
		}
	}

	return \@return;
}

1;
