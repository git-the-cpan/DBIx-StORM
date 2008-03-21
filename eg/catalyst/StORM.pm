package Catalyst::Model::StORM;

use strict;
use warnings;
use base 'Catalyst::Model';

use DBIx::StORM;
use NEXT;

our $VERSION = "0.02";

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
	my $self  = $class->NEXT::new(@_);

	$self->{storm} =
		DBIx::StORM->connect(@{ $self->{connect_info} })
			or die("DBI connection error");

	return $self;
}

sub storm {
	my $self = shift;
	$self->{storm}->ping
		or $self->{storm} =
			DBIx::StORM->connect(@{ $self->{connect_info} });
	return $self->{storm};
}

sub dbi {
	my $self = shift;
	return $self->{storm}->dbi;
}

1;
__END__

=head1 NAME

Catalyst::Model::StORM - Catalyst model for DBIx::StORM

=head1 SYNOPSIS

  use base qw/Catalyst::Model::StORM/;

  __PACKAGE__->config(
    connect_info => ['dbi:mysql:database=web', 'user', 'password']
  );

=head1 DESCRIPTION

Wraps a DBIx::StORM connection in a Catalyst::Model.

You should call the class config() method to configure the database. The
connect_info parameter should be set to an arrayref of parameters as passed
to DBIx::StORM->connect().

The model can be directly hash dereferenced to access tables:

  # Set $table to a DBIx::StORM::Table
  my $table = $c->model->{my_table};

=head1 METHODS

=head2 storm

Fetch the DBIx::StORM connection object.

=head2 dbi

Fetch the DBI connectio object. This is a shorthand for $model->storm->dbi

=head2 set_request

Set the current Catalyst object to the parameter passed in. This is used
for debugging purposes.

=head1 SEE ALSO

L<DBIx::StORM>

=head1 AUTHOR

Luke Ross, E<lt>luke@lukeross.name<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2008 by Luke Ross

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
