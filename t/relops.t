use NetAddr::IP;

# $Id: relops.t,v 1.3 2003/02/12 00:09:58 lem Exp $

BEGIN {
@gt = (
	  [ '255.255.255.255/32', '0.0.0.0/0' ],
	  [ '10.0.1.0/16', '10.0.0.1/24' ],
	  [ '10.0.0.1/24', '10.0.0.0/24' ],
	  );

@ngt = (
	   [ '0.0.0.0/0', '255.255.255.255/32' ],
	   [ '10.0.0.0/24', '10.0.0.0/24' ],
	   );

@cmp = (
	   [ '0.0.0.0/0', '255.255.255.255/32', -1 ],
	   [ '10.0.0.0/16', '10.0.0.0/8', 1 ],
	   [ '10.0.0.0/24', '10.0.0.0/8', 1 ],
	   [ '255.255.255.255/32', '0.0.0.0/0', 1 ],
	   [ '142.52.5.87', '142.52.2.88', 1 ],
	   [ '10.0.0.0/24', '10.0.0.0/24', 0 ],
	   [ 'default', 'default', 0 ],
	   [ 'broadcast', 'broadcast', 0],
	   [ 'loopback', 'loopback', 0],
	   );

};

use Test::More tests => @gt + @ngt + (2 * @cmp);

for my $a (@gt) {
    my $a_ip = new NetAddr::IP $a->[0];
    my $b_ip = new NetAddr::IP $a->[1];

    ok($a_ip > $b_ip, "$a_ip > $b_ip");
}

for my $a (@ngt) {
    my $a_ip = new NetAddr::IP $a->[0];
    my $b_ip = new NetAddr::IP $a->[1];

    ok(!($a_ip > $b_ip), "$a_ip !> $b_ip");
}

for my $a (@cmp) {
    my $a_ip = new NetAddr::IP $a->[0];
    my $b_ip = new NetAddr::IP $a->[1];

    is($a_ip <=> $b_ip, $a->[2], "$a_ip <=> $b_ip is $a->[2]");
    is($a_ip cmp $b_ip, $a->[2], "$a_ip cmp $b_ip is $a->[2]");
}

