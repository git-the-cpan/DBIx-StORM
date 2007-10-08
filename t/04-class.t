# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 04-class.t'

#########################

use Test;
my $tests;
BEGIN { $tests = 8; plan tests => $tests };

use DBIx::StORM;
$DBIx::StORM::DEBUG = 0; # Quiet, please!

my $dbh;
eval '$dbh = DBIx::StORM->connect("dbi:DBM:");';
unless($dbh) {
	for(1 .. $tests) {
		skip("Skip DBD::DBM not available ($@)");
	}
} else {

$dbh->dbi->{RaiseError} = 1;
# Set up environment
$dbh->dbi->do("CREATE TABLE fruit (dKey INT, dVal VARCHAR(10))")
	or die($dbh->dbi->errstr());

ok(1); # If we made it this far, we're ok.

#########################

package Fruit;

use base "DBIx::StORM::Class";

__PACKAGE__->config(
	connection => ["dbi:DBM:"],
	table      => "fruit",
);

sub _init {
	my $self = shift;
	$self->_stash->{my_value} = 1;
}

sub my_method {
	my $self = shift;
	return $self->_stash->{my_value};
}

package main;

my $a = 1;
my $b = 2;
my $c = 3;
my $d = 'oranges';
my $e = q('";);
my $f = 'to delete';
my $g = 'apples';

# Try an insert
my $r;
ok($r = Fruit->new() and ref($r) and $r->isa("Fruit") and $r->{dKey} = $a and $r->{dVal} = $d and $r->commit);
ok($r = Fruit->new() and ref($r) and $r->isa("Fruit") and $r->{dKey} = $b and $r->{dVal} = $e and $r->commit);
ok($r = Fruit->new() and ref($r) and $r->isa("Fruit") and $r->{dKey} = $c and $r->{dVal} = $f and $r->commit);

# And an update
ok(Fruit->grep(sub { $_->{dKey} == $b })->update(sub { $_->{dVal} = $g }));

# Custom method
ok(Fruit->grep(sub { $_->{dVal} == $f })->lookup->my_method());

# And a delete
ok(Fruit->grep(sub { $_->{dVal} == $f })->delete);

# Try a select
my $row;
my $results = Fruit->grep(sub { $_->{dVal} eq $g });
my $result;
ok($results and scalar(@$results) == 1 and $result = $results->[0] and
   $result->{dKey} eq $b and $result->{dVal} eq $g);

# Cleanup
$dbh->dbi->do("DROP TABLE fruit");

}

