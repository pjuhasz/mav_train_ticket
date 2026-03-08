#!/usr/bin/perl

use strict;
use warnings;
use feature qw/say/;
use Data::Dumper;

package SSB {
	sub new {
		my ($class, $bin) = @_;

		my $self = {
			bits => unpack("B*", $bin),
			pos  => 0,
		};
		bless $self, $class;
	}

	sub read_bits {
		my ($self, $count) = @_;
		my $pack_str;
		if ($count > 16) {
			$pack_str = 'L<';
		} elsif ($count > 8) {
			$pack_str = 'S<';
		} else {
			$pack_str = 'C';
		}
		my $val = unpack $pack_str, pack 'b*', scalar reverse substr $self->{bits}, $self->{pos}, $count;
		$self->{pos} += $count;
		return $val;
	}

	sub read_ascii6 {
		my ($self, $count) = @_;
		my $str = "";
		for my $i (1..$count) {
			my $char = chr 32 + unpack "C", pack 'b*', scalar reverse substr $self->{bits}, $self->{pos}, 6;
			$self->{pos} += 6;
			$str .= $char ;
		}
		$str =~ s/ +$//;
		return $str;
	}

	sub skip_bits {
		my ($self, $count) = @_;
		$self->{pos} += $count;
	}
}

my $bin;

{
	local $/ = undef;
	$bin = <>;
}

my $ssb = SSB->new($bin);

my $header = {
	version => $ssb->read_bits(4),
	issuer  => $ssb->read_bits(14),
	id      => $ssb->read_bits(4),
	type    => $ssb->read_bits(5),
};

my $common = {
	adults   => $ssb->read_bits(7),
	children => $ssb->read_bits(7),
	specimen => $ssb->read_bits(1),
	class    => $ssb->read_bits(6),
	tcn      => $ssb->read_ascii6(14),
	year     => $ssb->read_bits(4),
	doy      => $ssb->read_bits(9),
};

my $ticket = {
	header => $header,
	common => $common
};

if ($header->{type} == 1) {
	my $irt = {
		subtype => $ssb->read_bits(2),
		is_station_code_alpha => $ssb->read_bits(1),
	};
	$irt->{subtype_text} = (qw/RES IRT BOA/)[$irt->{subtype}]; 
	if ($irt->{is_station_code_alpha}) {
		$irt->{departure_station} = $ssb->read_ascii6(5);
		$irt->{arrival_station}   = $ssb->read_ascii6(5);
	} else {
		$irt->{station_code_list_type} = $ssb->read_bits(4);
		$irt->{departure_station}      = $ssb->read_bits(28);
		$irt->{arrival_station}        = $ssb->read_bits(28);
	}
	$irt = {
		%$irt,
		departure_date       => $ssb->read_bits(9),
		departure_time       => $ssb->read_bits(11),
		train_numer          => $ssb->read_ascii6(5),
		coach_number         => $ssb->read_bits(10),
		seat_number          => $ssb->read_ascii6(3),
		overbooking          => $ssb->read_bits(1),
		information_messages => $ssb->read_bits(14),
		open_text            => $ssb->read_ascii6(27),
	};
	$ssb->skip_bits(1);
	$ticket->{irt} = $irt;
} elsif ($header->{type} == 2) {
	my $nrt = {
		return_journey_flag   => $ssb->read_bits(1),
		first_day_of_validity => $ssb->read_bits(9),
		last_day_of_validity  => $ssb->read_bits(9),
		is_station_code_alpha => $ssb->read_bits(1),
	};
	if ($nrt->{is_station_code_alpha}) {
		$nrt->{departure_station} = $ssb->read_ascii6(5);
		$nrt->{arrival_station}   = $ssb->read_ascii6(5);
	} else {
		$nrt->{station_code_list_type} = $ssb->read_bits(4);
		$nrt->{departure_station}      = $ssb->read_bits(28);
		$nrt->{arrival_station}        = $ssb->read_bits(28);
	}
	$nrt = {
		%$nrt,
		information_messages => $ssb->read_bits(14),
		open_text            => $ssb->read_ascii6(37),
	};
	$ssb->skip_bits(3);
	$ticket->{nrt} = $nrt;
} elsif ($header->{type} == 3) {
	my $grt = {
		return_journey_flag   => $ssb->read_bits(1),
		first_day_of_validity => $ssb->read_bits(9),
		last_day_of_validity  => $ssb->read_bits(9),
		is_station_code_alpha => $ssb->read_bits(1),
	};
	if ($grt->{is_station_code_alpha}) {
		$grt->{departure_station} = $ssb->read_ascii6(5);
		$grt->{arrival_station}   = $ssb->read_ascii6(5);
	} else {
		$grt->{station_code_list_type} = $ssb->read_bits(4);
		$grt->{departure_station}      = $ssb->read_bits(28);
		$grt->{arrival_station}        = $ssb->read_bits(28);
	}
	$grt = {
		%$grt,
		name_of_group_leader => $ssb->read_ascii6(12),
		countermark          => $ssb->read_bits(8),
		information_messages => $ssb->read_bits(14),
		open_text            => $ssb->read_ascii6(24),
	};
	$ssb->skip_bits(1);
	$ticket->{grt} = $grt;
} elsif ($header->{type} == 4) {
	my $rpt = {
		subtype => $ssb->read_bits(2),
		first_day_of_validity => $ssb->read_bits(9),
		last_day_of_validity  => $ssb->read_bits(9),
		number_of_days_travel => $ssb->read_bits(7),
		country_code          => [
			$ssb->read_bits(7),
			$ssb->read_bits(7),
			$ssb->read_bits(7),
			$ssb->read_bits(7),
			$ssb->read_bits(7),
		],
		second_page           => $ssb->read_bits(1),
		information_messages  => $ssb->read_bits(14),
		open_text             => $ssb->read_ascii6(40),
	};
	$rpt->{subtype_text} = ('INTERAIL', 'EURAIL EUROPE', 'EURAIL OVERSEAS')[$rpt->{subtype}]; 

	$ssb->skip_bits(2);
	$ticket->{rpt} = $rpt;
} else {
	warn "Unsupported ticket type $header->{type}";
	$ssb->skip_bits(319);
}


print Dumper $ticket;

