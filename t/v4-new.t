use NetAddr::IP;

# $Id: v4-new.t,v 1.5 2002/12/27 20:37:55 lem Exp $

BEGIN {
our @a = (
	 [ 'localhost', '127.0.0.1' ],
	 [ 0x01010101, '1.1.1.1' ],
	 [ 1, '0.0.0.1' ],
	 [ 'default', '0.0.0.0' ],
	 [ 'any', '0.0.0.0' ],
	);

our @m = (
	 [ 0, '0.0.0.0' ],
	 [ 1, '128.0.0.0' ],
	 [ 2, '192.0.0.0' ],
	 [ 4, '240.0.0.0' ],
	 [ 8, '255.0.0.0' ],
	 [ 16, '255.255.0.0' ],
	 [ 17, '255.255.128.0' ],
	 [ 24, '255.255.255.0' ],
	 [ 'default', '0.0.0.0' ],
	 [ 32, '255.255.255.255' ],
	 [ 'host', '255.255.255.255' ],
	 [ 0xffffff00, '255.255.255.0' ],
	 [ '255.255.255.240', '255.255.255.240' ],
	 [ '255.255.128.0', '255.255.128.0' ],
	 [ 0b11111111111111110000000000000000, '255.255.0.0' ],
	 );
};

use Test::More tests => (4 * scalar @a * scalar @m) + 4;

ok(! defined NetAddr::IP->new('256.1.1.1'), "Invalid IP returns undef");
ok(! defined NetAddr::IP->new('256.256.1.1'), "Invalid IP returns undef");
ok(! defined NetAddr::IP->new('256.256.256.1'), "Invalid IP returns undef");
ok(! defined NetAddr::IP->new('256.256.256.256'), "Invalid IP returns undef");

for my $a (@a) {
    for my $m (@m) {
	my $ip = new NetAddr::IP $a->[0], $m->[0];
	is($ip->addr, $a->[1]);
	is($ip->mask, $m->[1]);
	is($ip->bits, 32);
	is($ip->version, 4);
    }
}

