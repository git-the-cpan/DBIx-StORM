#!/usr/bin/perl

package DBIx::StORM::TiedRecord;

use strict;
use warnings;

sub TIEHASH {
	my ($class, $result) = @_;
	my $self = { result => $result };
	return bless $self => $class;
}

sub FETCH {
	my ($self, $index) = @_;

	my @result = $self->{result}->_build_column_information_for_get($index);
	return undef unless @result;

	if (ref $result[0]) {
		# We have a foreign key column
		$result[0];
	} else {
		return $self->{result}->_get_simple_value(@result);
	}
}

sub STORE {
	my ($self, $index, $newval) = @_;

	my @col = $self->{result}->_build_column_information_for_get($index);
	die("Cannot update this field: $index") unless @col;

	my $result = $self->{result};
	if (ref $col[0]) {
		# We're updating a foreign key columnn
		$result->_update_field($col[1], $newval);
	} else {
		# We're updating a simple value
		$result->_update_field($col[0], $newval);
	}
	$result->commit if ($$result->{commit});

	return $result;
}

sub EXISTS {
	my ($self, $index) = @_;
	return defined($self->FETCH($index));
}

sub FIRSTKEY {
	my $self = shift;
	$self->{fields} ||=
		{ map { $_ => 1} $self->{result}->_fields };

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
}

1;
