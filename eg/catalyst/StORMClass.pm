package Catalyst::Model::StORMClass;

use strict;
use warnings;
use base 'Catalyst::Model';

use DBIx::StORM::Class;
use NEXT;

our $VERSION = "0.01";

sub ACCEPT_CONTEXT {
	my ($self, $c) = @_;

	no warnings "redefine";
	*DBIx::StORM::_debug = sub {
		my $class = shift;
		my $level = shift;

	        if ($level <= $DBIx::StORM::DEBUG) {
			$c->log->debug(@_) if $c->debug;
	        }
	};

	return $self;
}

sub new {
	my $class = shift;
	return $class->NEXT::new( @_ );
}

sub config {
	my ($package, @config) = @_;

	no strict "refs";

	my $target_package = $package->_target_package_name;

	push @{ $target_package . "::ISA" }, "DBIx::StORM::Class";

	# Copy over subroutines
	while(my($n, $sym) = each %{ $package . "::" }) {
		if (my $code =  *{$sym}{CODE}) {
			*{ $target_package . "::$n" } = $code;
		}
	}

	$target_package->config(@config) if @config;
	$package->SUPER::config(@config);
}

sub _target_package_name {
	my $package = shift;

	return $package . "::Implementation";
}

sub all {
	my $self = shift;
	my $package = ref $self || $self;;

	no strict "refs";

	my $target_package = $package->_target_package_name;

	return $target_package->all;
}

sub connection {
        my $self = shift;
        my $package = ref $self || $self;;

        no strict "refs";

        my $target_package = $package->_target_package_name;

        return $target_package->connection;
}

sub grep {
	my $self = shift;

	return $self->all->grep(@_);
}

1;
__END__

=head1 NAME

Catalyst::Model::StORMClass - Catalyst model for DBIx::StORM::Class

=head1 SYNOPSIS

  use base qw(Catalyst::Model::StORMClass);

  __PACKAGE__->config(
    connect_info => ['dbi:mysql:database=web', 'user', 'password']
    table        => "my_table"
  );

=head1 DESCRIPTION

Wraps a DBIx::StORM connection in a Catalyst::Model.

You should call the class config() method to configure the database. The
connect_info parameter should be set to an arrayref of parameters as passed
to DBIx::StORM->connect().

=head1 METHODS

=head2 all

Fetch the DBIx::StORM::Table

=head2 set_request

Set the current Catalyst object to the parameter passed in. This is used
for debugging purposes.

=head1 SEE ALSO

L<DBIx::StORM::Class>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.name<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2008 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
