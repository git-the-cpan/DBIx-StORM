#!/usr/bin/perl

package DBIx::StORM::TiedCallback;

use strict;
use warnings;

sub TIESCALAR {
	my ($class, %details) = @_;

	my $self = { %details };

	return bless $self => $class;
}

sub FETCH {
	my $self = shift;
	if ($self->{fetch}) {
		return $self->{fetch}->();
	}
}

sub STORE {
	my $self = shift;
	my $newval = shift;

	if ($self->{store}) {
		return $self->{store}->($newval);
	}
}

1;
