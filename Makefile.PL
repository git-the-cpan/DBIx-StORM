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
	NaturalDocs --input $ip --output HTML $op --project $proj

MAKE_FRAG
	};
	return $@ ? "" : $_;
}

WriteMakefile(
    NAME              => 'DBIx::StORM',
    VERSION_FROM      => 'lib/DBIx/StORM.pm', # finds $VERSION
    PREREQ_PM         => {
         B             => 0,
        "B::Concise"   => 0,
         Carp          => 0,
         constant      => 0,
         DBI           => 0,
         FindBin       => 0,
         overload      => 0,
        "XML::XPath"   => 0,
                         },
    ABSTRACT_FROM     => 'lib/DBIx/StORM.pm', # retrieve abstract from module
    AUTHOR            => 'Luke Ross <luke@lukeross.name>'
);
