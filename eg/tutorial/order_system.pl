#!/usr/bin/perl

use strict;
use warnings;

use DBIx::StORM;

$DBIx::StORM::DEBUG = 0; # Disable debug for prettier output

my $db = DBIx::StORM->connect("DBI:mysql:database=test")
	or die("Cannot connect to database - please check database settings");

my $mode_of_operation = shift || "help";

# Handlers for the various modes of operation
my %routines = (
	# Print a helpful usage message
	help => sub {
		print <DATA>;
		exit(1); # We didn't do anything
	},
	# Creating a new order
	create => sub {
		my ($customer_name, $customer_address) = @ARGV;

		# Insert a new row into the database
		my $order = $db->{orders}->insert(sub {
			# Set the customer name...
			$_->{customer_name} = $customer_name;
			# ...and their address
			$_->{customer_address} = $customer_address;
		});

		print "Your order was successfully created - order id ",
			$order->{id}, "\n";
		exit(0); # Success
	},
	# Adding an order item to an existing order
	add => sub {
		my ($order_id, $product_id, $description, $qty) = @ARGV;

		# Quantity should be positive
		if (not defined $qty or $qty < 1) {
			$qty = 1;
		}

		# Fetch the order Record object
		my $order = $db->{orders}->grep(sub {
			$_->{id} == $order_id
		})->lookup;

		# Was it in the database?
		if (not $order) {
			die("No such order: $order_id");
		}

		# Now insert the row for the order item
		$db->{order_items}->insert(sub {
			# It's associated with $order
			$_->{order} = $order;

			# And set the other fields
			$_->{product_id}  = $product_id;
			$_->{description} = $description;
			$_->{quantity}    = $qty;
		});

		exit(0); # Success
	},
	# Display information about an order and associated order items
	display => sub {
		my $order_id = shift @ARGV;

		# Fetch the order Record object, using the primary key
		# on the table.
		my $order = $db->{orders}->identity($order_id);

		# Was it in the database?
		if (not $order) {
			die("No such order: $order_id");
		}

		print "Order ", $order->{id}, "\n";

		# Prevent a warning in the sort below (annoying I know)
		our($a, $b);

		# Now get the items from the order_items table using the
		# foreign key in reverse.
		my $order_items = $order->associated("order_items")->sort(sub {
			$a->{product_id} <=> $b->{product_id}
		});

		# If there are some order items print them each in turn
		if ($order_items and @$order_items) {
			foreach my $item (@$order_items) {
				print " ", $item->{quantity}, " x ",
					$item->{product_id}, ": ",
					$item->{description}, "\n";
			}
		} else {
			print " This order has no items!\n"
		}

		exit(0);
	},
	# Change the quantity of an order item in an order
	change => sub {
		my ($order_id, $product_id, $new_qty) = @ARGV;

		# Ensure new quantity is at least one
		if ($new_qty < 1) { $new_qty = 1; }

		# Locate the order item Record
		my $order_item = $db->{order_items}->grep(sub {
			$_->{product_id} == $product_id and
			$_->{order} == $order_id
		})->lookup;

		# If we have an order item set the quantity
		if ($order_item) {
			$order_item->{quantity} = $new_qty;
			exit(0);
		} else {
			die("No item with product id $product_id in " .
				"order $order_id");
		}
	},
	# Remove an order item from an order
	remove => sub {
		my ($order_id, $product_id) = @ARGV;

		# Locate the order item Record
		my $order_item = $db->{order_items}->grep(sub {
			$_->{product_id} == $product_id and
			$_->{order} == $order_id
		})->lookup;

		# If we have the order item then delete it from the
		# database
		if ($order_item) {
			$order_item->delete;
			exit(0);
		} else {
			die("No item with product id $product_id in " .
				"order $order_id");
		}
	}
);

while(1) {
	# If an unknown command display the help message
	if (not $routines{$mode_of_operation}) {
		$mode_of_operation = "help";
	}

	# Call the handler
	$routines{$mode_of_operation}->();
}

# The help message is below
__DATA__
Ordering System (part of the DBIx::StORM tutorial)
(c) 2008 Luke Ross. This code is licensed under the same terms as Perl.

Usage:

 order_system.pl create <customer_name> <customer_address>
  Create a new order on the system and print the order number for the new
  order.    

 order_system.pl add <order_id> <product_id> <description> [<quantity>]
  Add an item to <order_id>. <quantity> defaults to 1.

 order_system.pl Change <order_id> <product_id> <new_qty>
  Change the quantity required of product <product_id> on order <order_id>.

 order_system.pl remove <order_id> <product_id>
  Remove product <product_id> on order <order_id>.

 order_system.pl display <order_id>
  Show information about order <order_id>.

__END__
