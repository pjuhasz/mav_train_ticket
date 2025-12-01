#!/usr/bin/perl

use strict;
use warnings;
use JSON::XS;
use utf8;

my $fn = $ARGV[0];
die "Usage: $0 <file.json>" unless defined $fn;

my $data;
{
	undef $/;
	open my $F, '<', $fn or die "Can't open file: $!";
	my $json = <$F>;
	close $F;

	eval {
		$data = decode_json($json);
		1;
	} or do {
		die "Can't decode file: $@";
	}
}

my %uic;

# some very common stations are weirdly missing from openstreetmap
my %mav_ref = (
	267  => 'Budapest-Keleti',
	3639 => 'Budapest-Déli',
);

for my $node (@{$data->{elements}}) {
	my $tags = $node->{tags};
	if (exists $tags->{uic_ref} and $tags->{uic_ref} =~ /^\d+$/ and defined $tags->{name}) {
		$uic{$tags->{uic_ref}} = $tags->{name};
	}
	if (exists $tags->{'ref:mav'}) {
		$mav_ref{$tags->{'ref:mav'}} = $tags->{name};
	}
}

binmode STDOUT, ':encoding(UTF-8)';

print <<EOH;
package mav_train_ticket

var uicStationNames = map[uint64]string{
EOH

for my $id (sort {$uic{$a} cmp $uic{$b}} keys %uic) {
	print "\t$id: `$uic{$id}`,\n";
}

print <<EOH;
}

var mavStationNames = map[uint64]string{
EOH

for my $id (sort {$mav_ref{$a} cmp $mav_ref{$b}} keys %mav_ref) {
	print "\t$id: `$mav_ref{$id}`,\n";
}

print "}\n\n"
