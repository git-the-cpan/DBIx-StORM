#!/usr/bin/perl

package DBIx::StORM::SQLDriver;

use strict;
use warnings;

use XML::XPath::Node::Element;

use Carp;

our $WHERE = {
        '//b:not[b:postinc/b:helem[r:column]/b:padhv]' => sub {
                my ($node, $op, $settings) = @_;
                my $new = XML::XPath::Node::Element->new("distinct", "r");
                $new->appendChild(($node->findnodes('b:postinc/b:helem/r:column'))[0]);
                my $padhv = ($node->findnodes('b:postinc/b:helem/b:padhv'))[0];
                $new->setAttribute("name", $padhv->getAttribute("name"));
                $settings->{replaceNode}->($node, $new);
        },
	'//b:defined[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("postOp", "r");
		$new->appendChild($_) foreach($node->getChildNodes);
		$new->setAttribute("name", "IS NOT NULL");
		$settings->{replaceNode}->($node, $new);
	},
	'//b:not[b:defined[not(*/@b)]]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("postOp", "r");
		$new->appendChild($_) foreach($node->getChildNodes->[0]->getChildNodes);
		$new->setAttribute("name", "IS NULL");
		$settings->{replaceNode}->($node, $new);
	},
	'//b:nextstate[2]' => sub {
		my ($node, $op, $settings) = @_;
		$settings->{abort} = 1;
	},
	'/b:leavesub/b:lineseq[position()=1]/b:nextstate[position()=1]' => sub {
		my ($node, $op, $settings) = @_;
		$settings->{replaceNode}->($node, undef);
	},
	'/o:binOp[(name="!=" or name="=") and (r:column or r:foreignKey) and (r:perlVar/@undef or r:const/@undef)]' => sub {
		die("isnull detected")
	},
	'/b:leavesub[b:lineseq[not(*/@b)]]' => sub {
		my ($node, $op, $settings) = @_;
		my @n = $node->findnodes('b:lineseq/*[not(@b)]');
		$settings->{replaceNode}->($node, $n[0]);
	},
	'//b:helem[b:rv2hv/r:column]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("foreignKey", "r");
		my $new2 = XML::XPath::Node::Element->new("column", "r");
		$new2->setAttribute("name", $node->findvalue('const/@value'));
		my $node2 = ($node->findnodes('b:rv2hv/r:column'))[0];
		$new->setAttribute("name", $node2->getAttribute("name"));
		$new->appendChild($new2);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:helem[b:rv2hv/b:rv2sv/b:gv/@name="_"]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("column", "r");
		$new->setAttribute("name", $node->findvalue('const/@value'));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:padsv' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("perlVar", "r");
		$new->setAttribute("name", $node->getAttribute('name'));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:eq[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "=");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:const[@b]' => sub {
		my ($node, $op, $settings) = @_;
		$node->removeAttribute("b");
	},
	'//b:lt[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "<");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:gt[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", ">");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:le[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "<=");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:ge[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", ">=");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:and[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "AND");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:or[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "AND");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		my $brackets1 = XML::XPath::Node::Element->new("brackets", "r");
		$brackets1->appendChild($firstChild);
		my $brackets2 = XML::XPath::Node::Element->new("brackets", "r");
		$brackets2->appendChild($secondChild);
		$new->appendChild($brackets1);
		$new->appendChild($brackets2);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:seq[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "=");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:null[not(*)]' => sub {
		my ($node, $op, $settings) = @_;
		# Remove
		$settings->{replaceNode}->($node, undef);
	},
	'//b:null[not(*/@b) and not(*[2])]' => sub {
		my ($node, $op, $settings) = @_;
		# Remove
		$settings->{replaceNode}->($node, $node->getFirstChild());
	},
};

our $ORDER = {
	# Urghh! This runs as "find me an ncmp opcode, which contains two
	# hash lookups. One should be against $a, the other $b, but both
	# using the same key.
	# This matches $a->{mykey} <=> $b->{mykey} but not any other
	# variables, nor if the keys disagree.
	'//b:ncmp[
		b:helem[
			b:const/@value = ../b:helem[
				b:rv2hv/b:padsv/@name="$b"
			]/b:const/@value
		]/b:rv2hv/b:padsv/@name="$a"
		and 
		b:helem/b:rv2hv/b:padsv/@name="$b"
	]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("sort", "r");
		my @nodes = $node->findnodes("b:helem/b:rv2hv/b:padsv");
		my $order = ($nodes[0]->getAttribute("name") eq '$a') ?
			"ASC" : "DESC";
		$new->setAttribute("direction", $order);
		@nodes = $node->findnodes("//b:const");
		$new->setAttribute("column", $nodes[0]->getAttribute("value"));
		$settings->{replaceNode}->($node, $new);
	},
	# It seems sometimes the variable name is mangled!
	'//b:ncmp[
		b:helem[
			b:const/@value = ../b:helem[
				b:rv2hv/b:rv2sv/b:gv/@name="b"
			]/b:const/@value
		]/b:rv2hv/b:rv2sv/b:gv/@name="a"
		and 
		b:helem/b:rv2hv/b:rv2sv/b:gv/@name="b"
	]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("sort", "r");
		my @nodes = $node->findnodes("b:helem/b:rv2hv/b:rv2sv/b:gv");
		my $order = ($nodes[0]->getAttribute("name") eq 'a') ?
			"ASC" : "DESC";
		$new->setAttribute("direction", $order);
		@nodes = $node->findnodes("//b:const");
		$new->setAttribute("column", $nodes[0]->getAttribute("value"));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:ncmp[
		b:helem[
			b:const/@value = ../b:helem[
				b:rv2hv/b:rv2sv/b:gv/@name="b"
			]/b:const/@value
		]/b:rv2hv/b:rv2sv/b:gv/@name="a"
		and 
		b:helem/b:rv2hv/b:rv2sv/b:gv/@name="b"
	]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("sort", "r");
		my @nodes = $node->findnodes("b:helem/b:rv2hv/b:rv2sv/b:gv");
		my $order = ($nodes[0]->getAttribute("name") eq 'a') ?
			"ASC" : "DESC";
		$new->setAttribute("direction", $order);
		@nodes = $node->findnodes("//b:const");
		$new->setAttribute("column", $nodes[0]->getAttribute("value"));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:ncmp[
		b:helem[
			b:const/@value = ../b:helem[
				b:rv2hv/b:rv2sv/b:gv/@name="b"
			]/b:const/@value
		]/b:rv2hv/b:rv2sv/b:gv/@name="a"
		and 
		b:helem/b:rv2hv/b:rv2sv/b:gv/@name="b"
	]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("sort", "r");
		my @nodes = $node->findnodes("b:helem/b:rv2hv/b:rv2sv/b:gv");
		my $order = ($nodes[0]->getAttribute("name") eq 'a') ?
			"ASC" : "DESC";
		$new->setAttribute("direction", $order);
		@nodes = $node->findnodes("//b:const");
		$new->setAttribute("column", $nodes[0]->getAttribute("value"));
		$settings->{replaceNode}->($node, $new);
	},
	# And the same for scmp
	'//b:scmp[
		b:helem[
			b:const/@value = ../b:helem[
				b:rv2hv/b:padsv/@name="$b"
			]/b:const/@value
		]/b:rv2hv/b:padsv/@name="$a"
		and 
		b:helem/b:rv2hv/b:padsv/@name="$b"
	]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("sort", "r");
		my @nodes = $node->findnodes("b:helem/b:rv2hv/b:padsv");
		my $order = ($nodes[0]->getAttribute("name") eq '$a') ?
			"ASC" : "DESC";
		$new->setAttribute("direction", $order);
		@nodes = $node->findnodes("//b:const");
		$new->setAttribute("column", $nodes[0]->getAttribute("value"));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:nextstate[2]' => sub {
		my ($node, $op, $settings) = @_;
		$settings->{abort} = 1;
	},
	'/b:leavesub/b:lineseq[position()=1]/b:nextstate[position()=1]' => sub {
		my ($node, $op, $settings) = @_;
		$settings->{replaceNode}->($node, undef);
	},
	'/b:leavesub[b:lineseq[not(*/@b)]]' => sub {
		my ($node, $op, $settings) = @_;
		my @n = $node->findnodes('b:lineseq/*[not(*/@b)]');
		$settings->{replaceNode}->($node, $n[0]);
	},
	'//b:null[b:or[not(*/@b)]]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("or", "r");
		$new->appendChild($_)
			foreach $node->getFirstChild->getChildNodes;
		$settings->{replaceNode}->($node, $new);
	}
};

our $UPDATE = {
	'//b:nextstate[position()=1]' => sub {
		my ($node, $op, $settings) = @_;
		$settings->{replaceNode}->($node, undef);
	},
	'//b:nextstate[position()!=1]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("nextUpdate", "r");
		$settings->{replaceNode}->($node, $new);
	},
	'/b:leavesub[b:lineseq[not(*/@b)]]' => sub {
		my ($node, $op, $settings) = @_;
		my @n = $node->findnodes('b:lineseq/*[not(*/@b)]');
		my $new = XML::XPath::Node::Element->new("clauses", "r");
		$new->appendChild($_) foreach(@n);
		$settings->{replaceNode}->($node, $new);
	},
	'//b:helem[b:rv2hv/b:rv2sv/b:gv/@name="_"' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("column", "r");
		$new->setAttribute("name", $node->findvalue('const/@value'));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:padsv' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("perlVar", "r");
		$new->setAttribute("name", $node->getAttribute('name'));
		$settings->{replaceNode}->($node, $new);
	},
	'//b:sassign[not(*/@b)]' => sub {
		my ($node, $op, $settings) = @_;
		my $new = XML::XPath::Node::Element->new("binOp", "r");
		$new->setAttribute("name", "=");
		my $firstChild = $node->getFirstChild();
		my $secondChild = $firstChild->getNextSibling();
		$new->appendChild($firstChild);
		$new->appendChild($secondChild);
		$settings->{replaceNode}->($node, $new);
	},
};

sub new {
	my $class = shift;
	my $self = {
		primary_keys => { },
		foreign_keys => { },
		tables => { }
	};
	return bless $self => $class;
}

sub _fetch_primary_key {
	my $self = shift;
	my $table = shift;

	return map { $table->name() . "->$_" } grep { $_ }
		$table->_storm->dbi->primary_key(undef, undef, $table->name() );
}

sub primary_key {
	my $self = shift;
	my $table = shift;
	my @toreturn;

	$self->{primary_keys}->{$table->name} ||= [ $self->_fetch_primary_key($table) ];

	return [ @{ $self->{primary_keys}->{$table->name} } ];
}

=begin NaturalDocs

Method: foreign_keys (instance)

  Return a set of foreign keys in this table that point to primary keys in
  other tables and cache the result.

  This is a wrapper around <_fetch_foreign_keys> which offers cachine of 
  table information. It is not normally necessary to override this method.

Parameters:

  $table - The <DBIx::StORM::Table> object to get foreign keys for

Returns:

  HashRef - A mapping of foreign keys keys to primary key values. Each key is
            a field name, and each value is a string of the format
            "table_name->field_name"

=end NaturalDocs

=cut

sub foreign_keys {
	my $self = shift;
	my $table = shift;
	my @toreturn;

	if (not $self->{foreign_keys}->{$table->name}) {
		$self->{foreign_keys}->{$table->name} = { $self->_fetch_foreign_keys($table) };
	}

	DBIx::StORM->_debug(3, "Foreign keys for table ", $table->name(), ": ", join(",", map { $_ . "=>" . $self->{foreign_keys}->{$table->name()}->{$_} } keys %{ $self->{foreign_keys}->{$table->name()} } ), "\n");

	return $self->{foreign_keys}->{$table->name()};
}

=begin NaturalDocs

Method: _fetch_foreign_keys (instance)

  Return a set of foreign keys in this table that point to primary keys in
  other tables.

  This is the generic method that uses DBI's foreign_key_info(), and is
  intended to be overridden when the DBI DBD doesn't provide a working method
  for this call.

Parameters:

  $table - The <DBIx::StORM::Table> object to get foreign keys for

Returns:

  Hash - A mapping of foreign keys keys to primary key values. Each key is
         a field name, and each value is a string of the format
         "table_name->field_name"

=end NaturalDocs

=cut

sub _fetch_foreign_keys {
	my $self = shift;
	my $table = shift;
	my %toreturn;

	my $sth = $table->_storm->dbi->foreign_key_info(undef,undef,undef,undef,undef,$table->name());

	unless($sth) {
		$table->_storm->_debug(1,
			"Bad FK lookup for table ". $table->name());
		return;
	}

	while(my $row = $sth->fetchrow_arrayref()) {
		next unless ($row->[7] and $row->[3]);
		$toreturn{ $row->[7] } = $row->[2] . "->" . $row->[3];
	}

	$sth->finish();

	return %toreturn;
}

sub add_hint {
	my $self = shift;
	my $hint_type = shift;
	my $hint_value = shift;

	if ($hint_type eq "primary_key") {
		croak "Bad primary key specification '$hint_value'" unless
			($hint_value =~ /^(.*)->(.*)$/);
		push @{ $self->{primary_keys}->{$1} }, $hint_value;
	} elsif ($hint_type eq "foreign_key") {
		if (keys(%$hint_value) != 1) {
			croak "Can only process one foreign key hint at a time";
		}

		my $from_spec = (keys %$hint_value)[0];
		my $to_spec = (values %$hint_value)[0];

		croak "Bad from foreign key specification '$from_spec'" unless
			(my ($from_t, $from_f) = $from_spec =~ /^(.*)->(.*)$/);

		croak "Bad to foreign key specification '$to_spec'" unless
			($to_spec =~ /^(.*)->(.*)$/);

		$self->{foreign_keys}->{$from_t}->{$from_f} = $to_spec;
	} else {
		carp "Cannot understand hint '$hint_type'";
	}
}

sub _build_columns {
	my $self = shift;
	my $table_object = shift;
	my $tables = shift;
	my $columns = shift;
	my $finding = shift;
	my $required = shift;
	my $table_id = shift;

	COLUMN_LOOP:
	foreach my $to_parse (@$finding) {
		die("bad column specificiation: $to_parse") unless
			($to_parse =~ m/^(.*?)->(.*)/);
		my $table = $1;
		my $table_spec = $1;
		my $parsing = $2;

		if (not $tables->{$table_spec}) {
			my $table_alias = "t" . ++$$table_id;
			my $clause = "$table AS $table_alias";
			$tables->{$table_spec} = {
				table_name => $table, # The real table name
				table_spec => $table_spec, # The FK path
				table_alias => $table_alias, # t + number
				table_clause => \$clause # SQL clause
			};
		}

		my $current_table = $tables->{$table_spec};

		while($parsing =~ m/^(.*?)->(.*)/) {
			my $this = $1;
			$parsing = $2;
			#print "Parsing $parsing\n";
			my $new_spec = $current_table->{table_spec} . "->$this";

			my $new_path = $self->foreign_keys($table_object->_storm()->{$current_table->{table_name}})->{$this};
			if (not $new_path) {
				if($required) { die("Cannot get a foreign key from $new_spec"); }
				next COLUMN_LOOP;
			}
			my ($new_table, $new_column) = $new_path =~ m/(.*)->(.*)/;
			
			if (not $tables->{$new_spec}) {
				my $table_alias = "t" . ++$$table_id;

				$tables->{$new_spec} = {
				table_name => $new_table, # The real table name
				table_spec => $new_spec, # The FK path
				table_alias => $table_alias, # t + number
				table_clause => $current_table->{table_clause}
				};

				my $prev_alias = $current_table->{table_alias};

				${ $current_table->{table_clause} } .= " LEFT JOIN $new_table AS $table_alias ON ($prev_alias.$this = $table_alias.$new_column)";
			}

			$current_table = $tables->{$new_spec};
		}

		# Now we have just the column name to look up in the current
		# table
		$columns->{$to_parse} = $current_table->{table_alias} . ".$parsing";
	}
}

sub do_insert {
	my $self = shift;
	my %params = @_;

	my $content = $params{content};
	my $table   = $params{table};

	my @mapping =   keys   %$content;
	my $values  = [ values %$content ];
	# If we have a deflater, let it munge @values as desired
	if (my @deflaters = $table->_storm->_inflaters) {
		foreach(@deflaters) {
			$values = $_->deflate($table->_storm, $values, \@mapping);
		}
	}

	my $query = "INSERT INTO " . $table->name . " (";
	$query .= join(", ", map { s/.*->//; $_ } @mapping);
	$query .= ") VALUES (";
	$query .= join(", ", map { "?" } @$values);
	$query .= ")";

	DBIx::StORM->_debug(2, "exec query: $query\n");
	DBIx::StORM->_debug(2, "bindings  : ". join(",", @$values). "\n");

	defined($table->_storm->dbi->do($query, { }, @$values))
	or return;

	return $self->_last_insert_id($table);
}

sub _last_insert_id {
	my $self = shift;
	my $table = shift;

	my $pk_map = { };

	my $pks = $self->primary_key($table);
	foreach my $pk (@$pks) {
		my $field = $pk;
		$field =~ s/.*->//;
		my $val = $table->_storm->dbi->last_insert_id(undef,
			undef, $table->name, $field);
		$table->_storm->_debug(3, "Doing last insert lookup on table=" . $table->name . ", field=$field, val=" . (defined $val ? $val : "(undef)") . "\n");
		$pk_map->{$pk} = $val if (defined $val);
	}

	return keys(%$pk_map) ? $pk_map : undef;
}

sub do_query {
	my $self = shift;
	my $params = shift;

	my $tables = { };
	my $columns = { };
	my $query;
	my @bind_params = ();
	my $table_mapping;
	my $fk_colname_map = {};

	$params->{verb} ||= "SELECT";
	my $is_update = uc($params->{verb}) eq "UPDATE";
	my $is_delete = uc($params->{verb}) eq "DELETE";

	if ($is_delete) {

		$query = "DELETE FROM " . $params->{table}->name . " ";

	} elsif ($is_update) {

		$query = "UPDATE " . $params->{table}->name . " SET ";
		my $first_update = 1;
		my $doc = $params->{updates};
		if (ref($doc) eq "ARRAY") {
			my @fragments;
			my @values;
			foreach my $clause (@$doc) {
				push @fragments, shift(@$clause);
				push @values, @$clause;
			}

			# If we have a deflater, let it munge @values as desired
			if (my @deflaters = $params->{table}->_storm->_inflaters) {
				my @tweaked_fragments = map { $params->{table}->name . "->$_" } @fragments;
				foreach(@deflaters) {
					@values = $_->deflate($params->{table}->_storm, \@values, \@tweaked_fragments);
				}
			}

			$query .= join ", ", @fragments;
			push @bind_params, @values;
		} else {
			my $abort = 0;
			$query .= $self->_flatten_update($doc->getFirstChild, \$abort, $params->{table}, \@bind_params);
			die($abort) if $abort;
		}

	} else {

	my $table_id = 0;

	my $required_columns = [ @{ $params->{required_columns} } ];
	if ($params->{wheres}) {
		my $basename = $params->{table}->name;
		foreach my $doc (@{ $params->{wheres} }) {
			# If might be an array, in which case we assume the
			# caller has sorted out the column already.
			next if (ref($doc) eq "ARRAY");

			foreach my $fk ($doc->findnodes("//foreignKey")) {
				my $colname = $basename;
				my $col = $fk;
				while(1) {
					$colname .= "->" . $col->getAttribute("name");
					last unless $col = $col->getFirstChild;
				}
				$fk_colname_map->{$fk} = $colname;
				push @$required_columns, $colname;
			}
		}
	}

	$self->_build_columns($params->{table}, $tables, $columns, $required_columns, 1, \$table_id);
	$self->_build_columns($params->{table}, $tables, $columns, $params->{recommended_columns}, 0, \$table_id) if ($params->{recommended_columns});

	if ($params->{views} and not $is_update) {
		foreach my $view(sort keys %{ $params->{views} }) {
			$columns->{"VIEW->$view"} = $params->{views}->{$view} . " AS $view";
		}
	}

	# Build the SQL

	# Build the FROM clause of the SQL. If we only have one table
	# we don't need aliases so use just the table name.
	my $table_clause;
	if (1 == scalar keys %$tables) {
		my (undef, $table) = each %$tables;
		if (${ $table->{table_clause} } eq $table->{table_name} . " AS t1") {
			$table_clause = $table->{table_name};
			# And strip off the prefix from columns
			while (my($k) = each %$columns) { $columns->{$k} =~ s/^t1\.// };
		}
	}

	# ... otherwise we are probably using more than one table and so we
	# need to assemble the join.
	unless($table_clause) {
		$table_clause = join(",", map { ${ $tables->{$_}->{table_clause} } } grep { not m/->/ } keys %$tables);
	}

	if (not $params->{recommended_columns}) {
		$table_clause ||= $params->{table}->name;
		my $view_clause = $params->{views} ?
		", " . join(", ", map { $params->{views}->{$_} . " AS $_" } sort keys %{ $params->{views} })
		: "";
		$query = "SELECT *$view_clause FROM $table_clause";
	} else {
		$query = "SELECT " . join(",", values %$columns) . " FROM $table_clause";
		my $lc = 0;
		$table_mapping = {};
		while(my $entry = each %$columns) {
			$table_mapping->{$entry} = $lc++;
		}
	}

	}

	if ($params->{wheres} and @{ $params->{wheres} }) {
		$query .= " WHERE";
		my $first_where = 1;
		my $one_where = (scalar(@{ $params->{wheres} }) == 1);
		foreach my $doc (@{ $params->{wheres} }) {

			my $fragment;
			if (ref($doc) eq "ARRAY") {
				# We have a SQL fragment as a string
				my @doc_copy = @$doc;
				$fragment = shift @doc_copy;
				push @bind_params, @doc_copy;
			} else {
				# $doc is a tree
				my $abort = 0;
				$fragment = $self->_flatten_where($doc->getFirstChild, \$abort, $params->{table}, \@bind_params, $columns, $fk_colname_map);
				die($abort) if $abort;
			}

			if (not $first_where) {
				$query .= " AND ";
			} else {
				$first_where = 0;
			}

			if ($one_where) {
				$query .= " $fragment";
			} else {
				$query .= " ($fragment) ";
			}
		}
	}

	if ($params->{sorts}) {
		my $abort = 0;
		$query .= " ORDER BY " . join(",", map {
			$self->_flatten_order($_->getFirstChild, \$abort)
		} @{ $params->{sorts} });
		die("Can't handle sort statement: $abort") if $abort;
	}

	$query = $self->_final_fixup($params, $query);

	$self->_prepare_bind_params($params->{verb}, $table_mapping,
		\@bind_params);
	
	DBIx::StORM->_debug(2, "exec query: $query\n");
	DBIx::StORM->_debug(2, "bindings  : ". join(",", map { defined($_) ? "\"$_\"" : "(undef)" } @bind_params). "\n");

	if ($is_update or $is_delete) {
		return $params->{table}->_storm->dbi->do($query, { }, @bind_params);
	}

	my $sth = $params->{table}->_storm->dbi->prepare($query);
	$sth->execute(@bind_params);

	$table_mapping ||= $self->build_table_mapping($params->{table}, $sth, $params->{record_base_reference} || $params->{table}->name(), $self->{views});
	return ($sth, $table_mapping);
}

sub table_exists {
	my $self  = shift;
	my $dbh   = shift;
	my $table = shift;

	return 1 if ($self->{tables}->{$table});

	my $schema  = "";
	my $database = "";

	if ($table =~ m/(.*)\.(.*)\.(.*)/) {
		$database = $1;
		$schema   = $2;
		$table    = $3;
	} elsif ($table =~ m/(.*)\.(.*)/) {
		$schema   = $1;
		$table    = $2;
	}

	if ($dbh->tables($database, $schema, $table)) { return 1; }
	else { return; }
}

sub table_list {
	my $self = shift;
	my $dbh  = shift;

	my %table_list;
	my $sth = $dbh->table_info("", "", "", "'TABLE','VIEW'");
	while(my $row = $sth->fetchrow_hashref) {
		my $table_spec = [ $row->{TABLE_CAT},
		                   $row->{TABLE_SCHEM},
		                   $row->{TABLE_NAME}
		];

		my $quoted_name = $dbh->quote_identifier(@$table_spec);

		$table_list{$quoted_name} = $table_spec;
	}
	return \%table_list;
}

sub build_table_mapping {
	my $self = shift;
	my $table = shift;
	my $sth = shift;
	my $base = shift || $table->name();
	my $views = shift;

	my $views_start_at = 0;
	my $toreturn = { };
	die("No name array on statement handle") unless $sth->{NAME};

	if ($views) {
		$views_start_at = @{ $sth->{NAME} };
		foreach(reverse sort keys %$views) {
			$toreturn->{"VIEW->$_"} = $views_start_at--;
		}
	}

	my $lc = 0;
	foreach my $colname (@{ $sth->{NAME} }) {
		next if ($views_start_at and $lc >= $views_start_at);
		$toreturn->{"$base->$colname"} = $lc++;
	}

	return $toreturn;
}

sub opcode_map {
	my $self = shift;
	my $type = uc(shift);

	no strict "refs";
	return $$type;
}

sub _flatten_where {
	my($class, $node, $abort, $table, $params, $columns, $fks) = @_;

	     if ($node->getTagName eq "binOp")   {
		my $children = $node->getChildNodes;
		my $str1 = $class->_flatten_where($children->[0], $abort, $table, $params, $columns, $fks);
		my $str2 = $class->_flatten_where($children->[1], $abort, $table, $params, $columns, $fks);
		my $op = $node->getAttribute("name");
		return "$str1 $op $str2";
	} elsif ($node->getTagName eq "postOp") {
		my $str1 = $class->_flatten_where($node->getChildNodes->[0], $abort, $table, $params, $columns, $fks);
		my $op = $node->getAttribute("name");
		return "$str1 $op";
	} elsif ($node->getTagName eq "perlVar") {
		push @$params, $node->getAttribute("value");
		return "?";
	} elsif ($node->getTagName eq "const") {
		push @$params, $node->getAttribute("value");
		return "?";
        } elsif ($node->getTagName eq "foreignKey") {
                return $columns->{$fks->{$node}};
	} elsif ($node->getTagName eq "column") {
		return $node->getAttribute("name");
	} else {
		$$abort = "Unknown operation " . $node->getTagName;
	}
}

sub _flatten_order {
	my($class, $node, $abort) = @_;
	my @order;
	     if ($node->getTagName eq "sort")   {
		push @order, $node->getAttribute("column") . " " .
		             $node->getAttribute("direction");
	} elsif ($node->getTagName eq "or") {
		push @order, $class->_flatten_order($_, $abort)
			foreach $node->getChildNodes;
	} else {
		$$abort = "Unknown operation " . $node->getTagName;
	}
	return join(", ", @order);
}

sub _flatten_update {
	my($class, $node, $abort, $table, $params, $columns, $fks) = @_;

	     if ($node->getTagName eq "binOp")   {
		my $children = $node->getChildNodes;
		my $str1 = $class->_flatten_update($children->[0], $abort, $table, $params, $columns, $fks);
		my $str2 = $class->_flatten_update($children->[1], $abort, $table, $params, $columns, $fks);
		my $op = $node->getAttribute("name");
		return "$str2 $op $str1";
	} elsif ($node->getTagName eq "perlVar") {
		push @$params, $node->getAttribute("value");
		return "?";
	} elsif ($node->getTagName eq "column") {
		return $node->getAttribute("name");
	} elsif ($node->getTagName eq "nextUpdate") {
		return ",";
	} elsif ($node->getTagName eq "foreignKey") {
		return $columns->{$fks->{$node}};
	} elsif ($node->getTagName eq "clauses") {
		return join("", map {
			my $a = $class->_flatten_update($_, $abort, $table, $params, $columns, $fks);
		} $node->getChildNodes);
	} else {
		$$abort = "Unknown operation " . $node->getTagName;
	}
}

sub _prepare_bind_params {
	my ($self, $verb, $mapping, $params) = @_;

	return unless $mapping;

	my $reverse_mapping;
	while(my($k, $v) = each %$mapping) {
		$reverse_mapping->[$v] = $k;
	}

	for(my $i = 0; $i < @$params; ++$i) {
		next unless ref $params->[$i];

		die(sprintf('Column %s uses object %s', $reverse_mapping->[$i], overload::StrVal($params->[$i])));
	}
}

sub _final_fixup {
	my ($self, $params, $query) = @_;
	return $query;
}

1;
