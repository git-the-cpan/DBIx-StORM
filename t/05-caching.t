use strict;
use warnings;

use Test;
my $tests;
BEGIN { $tests = 3; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

use FindBin;
use lib $FindBin::Bin;
do "table_setup_generic.pl" or die $@;
die $@ if $@;

# Go remove the cache
delete $DBIx::StORM::RecordSet::recommended_columns->{fruit};
our $storm = DBIx::StORM->connect("dbi:DBM:");
$::storm->add_hint(primary_key => "fruit->id");

my $inflator = CheckQuery->new;
$storm->inflater($inflator);

use Data::Dumper;
my $value = $storm->{fruit}->lookup->{id};
ok($inflator->last_query, "SELECT * FROM fruit");

my $fruit = $storm->{fruit}->lookup;
$value = $fruit->{id};
ok($inflator->last_query, "SELECT id FROM fruit");

$value = $fruit->{name};
ok($inflator->last_query, "SELECT * FROM fruit WHERE id = ?");

package CheckQuery;

use base "DBIx::StORM::Inflater";

sub new {
	return bless { } => shift();
}

sub inflate {
	my $self = shift;
	$self->{last_query} = $_[2]->{Statement};
	return $self->SUPER::inflate(@_);
}

sub last_query {
	my $self = shift;
	return $self->{last_query};
}
