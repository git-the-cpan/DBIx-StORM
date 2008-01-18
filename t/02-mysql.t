# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 02-mysql.t'
# as long as you set the configuration below:
my $dsn      = "DBI:mysql:hostname=localhost:database=test";
my $user     = "root";
my $password = "";
#########################

use Test;
my $tests;
BEGIN { $tests = 11; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

my $dbh;
eval '$dbh = DBIx::StORM->connect($dsn,$user,$password);';
unless($dbh) {
	for(1 .. $tests) {
		skip("Skip mysql tests not configured correctly ($@)");
	}
} else {

$dbh->dbi->{RaiseError} = 1;
# Set up environment
$dbh->dbi->do("DROP TABLE IF EXISTS price")
	or die($dbh->dbi->errstr());
$dbh->dbi->do("DROP TABLE IF EXISTS fruit")
	or die($dbh->dbi->errstr());
$dbh->dbi->do("CREATE TABLE fruit (dKey INT PRIMARY KEY, dVal VARCHAR(10)) ENGINE=InnoDB")
	or die($dbh->dbi->errstr());
$dbh->dbi->do("CREATE TABLE price (fruit INT, price INT, FOREIGN KEY (fruit) REFERENCES fruit(dKey)) ENGINE=InnoDB")
	or die($dbh->dbi->errstr());

ok(1); # If we made it this far, we're ok.

#########################

my $a = 1;
my $b = 2;
my $c = 3;
my $d = 'oranges';
my $e = q('";);
my $f = 'to delete';
my $g = 'apples';

# Try an insert
ok(ref $dbh->{fruit}->insert(sub { $_->{dKey} = $a; $_->{dVal} = $d; }));
ok(ref $dbh->{fruit}->insert(sub { $_->{dKey} = $b; $_->{dVal} = $e; }));
ok(ref $dbh->{fruit}->insert(sub { $_->{dKey} = $c; $_->{dVal} = $f; }));
ok(ref $dbh->{price}->insert(sub { $_->{fruit} = $a; $_->{price} = $c; }));
ok(ref $dbh->{price}->insert(sub { $_->{fruit} = $b; $_->{price} = $a; }));

# And an update
ok($dbh->{fruit}->grep(sub { $_->{dKey} == $b })->update(sub { $_->{dVal} = $g }));

# And a delete
ok($dbh->{fruit}->grep(sub { $_->{dVal} == $f })->delete);

# Try a select
my $row;
my $results = $dbh->{fruit}->grep(sub { $_->{dVal} eq $g });
my $result;
ok($results and scalar(@$results) == 1 and $result = $results->[0] and
   $result->{dKey} eq $b and $result->{dVal} eq $g);

# Try an FK lookup
ok($dbh->{price}->grep(sub { $_->{fruit}->{dVal} eq $d })->lookup->{price} == $c);

# Try a sort
ok($dbh->{price}->grep(sub { $_->{fruit}->{dVal} eq $d })->sort(sub { $b->{price} <=> $a->{price} or $a->{fruit} cmp $b->{fruit} })->lookup);

# Cleanup
$dbh->dbi->do("DROP TABLE price");
$dbh->dbi->do("DROP TABLE fruit");

}
