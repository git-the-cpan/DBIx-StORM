use 5.006;
use ExtUtils::MakeMaker;

sub MY::postamble {
	$_ = eval {
		require FindBin;
		require File::Spec;
		my $ip = quotemeta(File::Spec->rel2abs("lib", $FindBin::Bin));
		my $op = File::Spec->rel2abs("doc", $FindBin::Bin);
		   $op = quotemeta(File::Spec->rel2abs("apidoc", $op));
		my $proj = quotemeta(File::Spec->rel2abs("naturaldocs", $FindBin::Bin));

		return <<"MAKE_FRAG";
apidoc:
	NaturalDocs -r --input $ip --output HTML $op --project $proj

checkpod:
	podchecker \$(MAN1PODS) \$(MAN3PODS)

MAKE_FRAG
	};
	return $@ ? "" : $_;
}

WriteMakefile(
	NAME          => 'DBIx::StORM',
	VERSION_FROM  => 'lib/DBIx/StORM.pm', # finds $VERSION
	PREREQ_PM     => {
		 B             => 0,
		 Carp          => 0,
		 constant      => 0,
		 DBI           => 0,
		 FindBin       => 0, # For the tests
		 overload      => 0,
		"Scalar::Util" => 1.14,
		"XML::XPath"   => 0,
	},
	ABSTRACT_FROM => 'lib/DBIx/StORM.pm', # retrieve from module
	AUTHOR        => 'Luke Ross <luke@lukeross.name>'
);
