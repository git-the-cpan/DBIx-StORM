#!/usr/bin/perl

package DBIx::StORM::RecordSetWithView;

use strict;
use warnings;

use base "DBIx::StORM::RecordSet";
use overload '@{}' => "_as_array", fallback => 1;

sub _new {
	my $class = shift;
	my $params = shift;

	my $self = { %$params };

	bless $self => $class;

	my $filter_id = $params->{parent}->_filter_id();
	foreach my $view(keys %{ $self->{new_views} }) {
		my $filter = $self->{new_views}->{$view};
		$filter_id .= "($view=$filter)";
		next if $self->{perl_filter};
		my $parsed = $self->_do_parse($filter);
		if (not $parsed) {
			$self->{perl_views}->{$view} = $filter;
		} else {
			$self->{views}->{$view} = $parsed;
		}
	}
	$self->{filter_id} = $filter_id;
	delete $self->{new_views};

	return $self;
}

1;
