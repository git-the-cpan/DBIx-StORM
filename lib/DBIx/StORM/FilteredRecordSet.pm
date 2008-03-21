#!/usr/bin/perl

package DBIx::StORM::FilteredRecordSet;

use strict;
use warnings;
use base "DBIx::StORM::RecordSet";
use overload '@{}' => "_as_array", fallback => 1;

use DBIx::StORM::LexBindings;

=begin NaturalDocs

Method: _new (private static)

  Create a new <DBIx::StORM::FilteredRecordSet> object

Parameters:

  $params - A hash reference to initialise the object with

Returns:

  A new <DBIx::StORM::FilteredRecordSet> object

=cut
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

	# If we've been given a glob of SQL, use it directly
	if ($self->{pre_parsed}) {
		push @{ $self->{wheres} }, $filter;
		delete $self->{pre_parsed};
		return $self;
	}

	my $parsed = $self->_do_parse($filter, "WHERE", binding => 1);
	if ($parsed) {
		# _build_where_clause() has poked the wheres into
		# $self->{wheres}
	} else {
		push @{ $self->{perl_wheres} }, $filter;
	}

	return $self;
}

=begin NaturalDocs

Method: _do_binding (private instance)

  Set up the where clause, performing any required variable binding

Parameters:

  $filter - The code reference being parsed
  $parsed - The SQL code built from the code reference

Returns:

  Nothing

=cut
sub _do_binding {
	my $self   = shift;
	my $filter = shift;
	my $parsed = shift;
	my $mode   = shift;

	if (uc($mode) ne "WHERE") {
		return $self->SUPER::_do_binding($filter, $parsed, $mode);
	}

	my $lexmap = DBIx::StORM::LexBindings->lexmap($filter);

	my ($document, $xp) = @$parsed;
	foreach my $node($xp->findnodes('//perlVar')) {
		no strict "refs";
		my $var = $node->getAttribute("name");
		return undef unless $var =~ m/^\$/;

		my $val;
		$val = defined($lexmap->{$var}) ? $lexmap->{$var} : $$_;

		$node->setAttribute("value", $val);

	}
	push @{ $self->{wheres} }, $document;

	return 1;
}

1;
