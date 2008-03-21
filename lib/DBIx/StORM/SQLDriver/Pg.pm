#!/usr/bin/perl

package DBIx::StORM::SQLDriver::Pg;

use strict;
use warnings;

use base "DBIx::StORM::SQLDriver";


sub _last_insert_id {

	my $self = shift;

	my $table = shift;

	my $oid = $table->_storm->dbi->selectall_arrayref(
	        "SELECT c.oid FROM pg_class c WHERE relname = ?",
	        { }, $table->name);
	$oid = $oid->[0]->[0];

	my $sql = <<"END";
SELECT a.attname, i.indisprimary, substring(d.adsrc for 128) AS def
FROM pg_index i, pg_attribute a, pg_attrdef d WHERE i.indrelid=$oid
AND d.adrelid=a.attrelid AND d.adnum=a.attnum AND a.attrelid=$oid AND
i.indisunique IS TRUE AND a.atthasdef IS TRUE AND i.indkey[0]=a.attnum
AND d.adsrc ~ '^nextval'
END
	#  attname | indisprimary |                    def
	# id      | t            | nextval('blog_comments_id_seq'::regclass)
	my $sth = $table->_storm->dbi->prepare($sql);
	$sth->execute();

	my $sth2 = $table->_storm->dbi->prepare("SELECT currval(?)");

	my $pk_map = { };
	while (my $row = $sth->fetchrow_arrayref()) {
		next unless $row->[2] =~ /^nextval\('([^']+)'::/o;
		my $seq = $1;
		my $col = $table->name . "->" . $row->[0];
		$sth2->execute($seq);
		my $r = $sth2->fetchrow_arrayref()->[0];
		$pk_map->{$col} = $r;
	}

	return keys(%$pk_map) ? $pk_map : undef;
}

1;
