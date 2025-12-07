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
my %mav_ref;

binmode STDERR, ':encoding(UTF-8)';

for my $node (@{$data->{stations}}) {
	next if $node->{isAlias};

	my $name = $node->{name};
	my $uic = $node->{code} =~ s/^0+//r;
	my $mav = $node->{baseCode};
	if (exists $uic{$uic}) {
		warn "Duplicate UIC code for $uic: $name vs $uic{$uic}";
	} else {
		$uic{$uic} = $name;
	}
	next unless $mav;
	if (exists $mav_ref{$mav}) {
		warn "Duplicate MAV code for $mav: $name vs $mav_ref{$mav}";
	} else {
		$mav_ref{$mav} = $name;
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
