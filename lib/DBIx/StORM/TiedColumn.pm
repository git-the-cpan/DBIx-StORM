#!/usr/bin/perl

package DBIx::StORM::TiedColumn;

use strict;
use warnings;

sub TIESCALAR {
	my ($class, $result, $field, $raw_field) = @_;

	my $self = {
		result    => $result,
		field     => $field,
		raw_field => $raw_field
	};

	return bless $self => $class;
}

sub FETCH {
	my $self = shift;
	return $self->{result}->_get_simple_value(
		$self->{field}, $self->{raw_field});
}

sub STORE {
	my $self = shift;
	my $newval = shift;
	my $result = $self->{result};

	$result->_update_field($self->{field}, $newval);
	$result->commit if ($$result->{commit});

	return $newval;
}

1;
