#!/usr/bin/perl

use strict;
use warnings;
use feature qw/say/;
use Data::Dumper;
use Compress::Zlib;

package Reader {
	sub new {
		my ($class, $text) = @_;

		my $self = {
			text => $text,
			pos  => 0,
		};
		bless $self, $class;
	}

	sub read {
		my ($self, $count) = @_;
		my $res = substr $self->{text}, $self->{pos}, $count;
		$self->{pos} += $count;
		$res =~ s/ +$//;
		return $res;
	}

	sub readn {
		my ($self, $count) = @_;
		my $res = substr $self->{text}, $self->{pos}, $count;
		$self->{pos} += $count;
		return 0+$res;
	}

}

my $bin;

{
	local $/ = undef;
	$bin = <>;
}

my $tlb = Reader->new($bin);

die "Not an UIC ticket\n" if $tlb->read(3) ne '#UT';

my $version = $tlb->readn(2);
my $issuer = $tlb->readn(4);
my $signature_id = $tlb->readn(5);
my $signature;
if ($version == 1) {
	$signature = $tlb->read(50);
} elsif ($version == 2) {
	$signature = $tlb->read(64);
} else {
	die "Unsupported ticket version $version\n";
}
my $uncompressed_length = $tlb->readn(4);

my $uncompressed = uncompress($tlb->read($uncompressed_length));

my $ticket = {
	envelope => {
		version => $version,
		issuer  => $issuer,
		signature_id => $signature_id,
		signature => $signature,
	}
};

my $content = Reader->new($uncompressed);

my $u_head = $content->read(6);
die "U_HEAD record not found\n" if $u_head ne 'U_HEAD';

my $header = {
	version      => $content->readn(2),
	length       => $content->readn(4),
	issuer       => $content->readn(4),
	key          => $content->read(20),
	edition_time => $content->read(12),
	flags        => $content->readn(1),
	language     => $content->read(2),
	language2    => $content->read(2),
};

$ticket->{header} = $header;

my $u_tlay = $content->read(6);
die "U_TLAY record not found\n" if $u_tlay ne 'U_TLAY';

my $layout = {
	version  => $content->readn(2),
	length   => $content->readn(4),
	standard => $content->read(4),
	n_fields => $content->readn(4),
	fields   => [],
};

for my $i (1..$layout->{n_fields}) {
	my $field = {
		row => $content->readn(2),
		col => $content->readn(2),
		H   => $content->readn(2),
		W   => $content->readn(2),
		fmt => $content->readn(1),
		len => $content->readn(4),
	};
	$field->{text} = $content->read($field->{len});
	push @{$layout->{fields}}, $field;
}

$ticket->{layout} = $layout;

my @rows = (' ' x 72) x 15;

for my $field (@{$layout->{fields}}) {
	substr $rows[$field->{row}], $field->{col}, $field->{W}, $field->{text};
	# TODO break lines when H > 1
}

my $rendered = join "\n", @rows;

$ticket->{rendered} = $rendered;

# TODO parse logical fields?

print Dumper $ticket;
