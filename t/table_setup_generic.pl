# This is used to set up some tables for generic regression tests

use DBIx::StORM;

eval '$::storm = DBIx::StORM->connect("dbi:DBM:");';
unless($::storm) {
	for(1 .. $tests) {
		skip("Skip DBD::DBM not available ($@)");
	}
	exit(0);
}

my $dbh = $::storm->dbi;

$dbh->{RaiseError} = 1;
$dbh->do("CREATE TABLE fruit (id INT, name VARCHAR(10))")
	or die($dbh->dbi->errstr());
$dbh->do("CREATE TABLE variety (name INT, fruit INT)")
	or die($dbh->dbi->errstr());

$::storm->add_hint(foreign_key => { "variety->fruit" => "fruit->id" });
$::storm->add_hint(primary_key => "fruit->id");
$::storm->add_hint(primary_key => "variety->name");

$::storm->{fruit}->insert(sub { $_->{id} = 1; $_->{name} = "apple"; });
$::storm->{fruit}->insert(sub { $_->{id} = 2; $_->{name} = "orange"; });
$::storm->{fruit}->insert(sub { $_->{id} = 3; $_->{name} = "peach"; });

$::storm->{variety}->insert(sub { $_->{fruit} = 1; $_->{name} = "cox"; });
$::storm->{variety}->insert(sub { $_->{fruit} = 1; $_->{name} = "braeburn"; });
$::storm->{variety}->insert(sub { $_->{fruit} = 3; $_->{name} = "hamburg"; });

sub pulldown {
	my $dbh = $::storm->dbi;
	$dbh->do("DROP TABLE fruit");
	$dbh->do("DROP TABLE variety");
}
