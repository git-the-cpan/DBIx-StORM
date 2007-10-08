#!/usr/bin/perl

package DBIx::StORM::OrderedRecordSet;

use strict;
use warnings;

use base "DBIx::StORM::RecordSet";
use overload '@{}' => "_as_array", fallback => 1;

sub _new {
	my $class = shift;
	my $params = shift;
	my $filter = $params->{filter};
	my $filter_id = ref $filter ? $filter : \$filter;

	my $self = {
		%$params,
		filter_id => $params->{parent}->_filter_id() . "$filter_id",
	};

	bless $self => $class;

	my $parsed = $self->_do_parse($filter, "ORDER");
	if ($parsed) {
		push @{ $self->{sorts} }, $parsed->[0];
	} else {
		push @{ $self->{perl_sorts} }, $filter;
	}

	return $self;
}

1;
