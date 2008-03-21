#!/usr/bin/perl

package DBIx::StORM::ParseCV;

use strict;
use warnings;

use B qw(class ppname main_start main_root main_cv cstring svref_2object
         SVf_IOK SVf_NOK SVf_POK SVf_IVisUV OPf_KIDS OPf_SPECIAL);
use Carp;
use XML::XPath;
use XML::XPath::Node::Element;
use XML::XPath::Node::Namespace;
use XML::XPath::Node::Attribute;

use DBIx::StORM;

sub parse {
	my ($class, $orig_cv, $map) = @_;

	my $cv = B::svref_2object($orig_cv) or return undef;

	my $context = my $document = XML::XPath::Node::Element->new();
	$document->appendNamespace(XML::XPath::Node::Namespace->new('xml',
		"http://www.w3.org/XML/1998/namespace"));
	$document->appendNamespace(XML::XPath::Node::Namespace->new('b',
		"http://lukeross.name/dbixstorm/opcode"));
	$document->appendNamespace(XML::XPath::Node::Namespace->new('r',
		"http://lukeross.name/dbixstorm/resultop"));

	my $opcode_map = { };
	$class->_build_tree($cv->ROOT, $document, $opcode_map, $cv);

	my $xpath = XML::XPath->new({ });
	$xpath->set_context($context); # This will *not* win me friends

	my $self = {
		cv => $cv,
		xpath => $xpath,
		map => $map
	};

	my $settings = {
		cv => $cv,
		abort => 0,
		replaceNode => sub {
			my ($oldNode, $newNode) = @_;
			my $parent = $oldNode->getParentNode;
			$parent->insertAfter($newNode, $oldNode) if $newNode;
			$parent->removeChild($oldNode);
		}
	};
	my $matched = 1;
	while($matched) {
		$matched = 0;
		while(my($xp, $sub) = each %$map) {
			foreach my $node ($xpath->findnodes($xp)) {
				$matched = 1;
				$sub->($node, $opcode_map->{$node}, $settings);
				return undef if $settings->{abort};
			}
		}
	}

	if ($xpath->findnodes('/b:leavesub')) {
		# We didn't manage to fully compile it
		return undef;
	}

	return [ $document, $xpath ];
}

sub _build_tree {
	my ($class, $op, $parent, $map, $cv) = @_;

	my $opname = $op->name;
	my $node = XML::XPath::Node::Element->new($opname, "b");
	$node->setAttribute("b", "1");
	$map->{$node} = $op; # Urgh! We want to hold this in case we need
	                     # it later.

	our %OPCODE_ATTRIBUTES;
	if (exists $OPCODE_ATTRIBUTES{$opname}) {
		while(my($attrname, $attrsub) = each
			%{ $OPCODE_ATTRIBUTES{$opname} }) {

			$node->setAttribute( $attrname, $attrsub->($op, $cv));
		}
	}
	$parent->appendChild($node);

	return unless $op->can("first");
	my $kid = $op->first;
	while(defined($kid) and not $kid->isa("B::NULL")) {
		$class->_build_tree($kid, $node, $map, $cv);
		$kid = $kid->sibling;
	}
}

our %OPCODE_ATTRIBUTES = (

gv => {
	name => sub {
		my ($op, $cv) = @_;
		if ($op->isa("B::SVOP")) {
			return $op->gv->SAFENAME;
		} else {
			return (($cv->PADLIST->ARRAY)[1]->ARRAY)[$op->padix]->SAFENAME;
		}
	}
},
const => {
	value => sub {
		my ($op, $cv) = @_;
		my $sv = ${$op->sv} ? $op->sv :
		        (($cv->PADLIST->ARRAY)[1]->ARRAY)[$op->targ];
		if (ref($sv) =~ m/::SPECIAL$/) {
			return ["Null", "sv_undef", "sv_yes", "sv_no"]->[$$sv];
		}
		if ($sv->FLAGS & B::SVf_NOK()) { return $sv->NV; }
		if ($sv->FLAGS & B::SVf_IOK()) { return $sv->int_value; }
		if ($sv->FLAGS & B::SVf_POK()) { return $sv->PV; }
		return "";
	}
},
padsv => {
	name => sub {
		my ($op, $cv) = @_;
		my $sv = (($cv->PADLIST->ARRAY)[0]->ARRAY)[$op->targ]->PV;
		return $sv;
	}
},

);


1;
