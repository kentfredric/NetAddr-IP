# This -*- perl -*- code excercises the basic v6 functionality

# $Id: v6-base.t,v 1.2 2002/12/10 16:55:52 lem Exp $

BEGIN { our @addr = qw(:: ::1 f34::123/40 ); };

use NetAddr::IP;
use Test::More tests => 2 * @addr + 4;

my($a, $ip, $test);

for $a (@addr) {
	$ip = new NetAddr::IP $a;
	$a =~ s,/\d+,,;
	isa_ok($ip, 'NetAddr::IP');
	is($ip->compact_addr, $a);
}

$test = new NetAddr::IP f34::1;
isa_ok($test, 'NetAddr::IP');
ok($ip->network->contains($test), "->contains");

$test = new NetAddr::IP f35::1/40;
isa_ok($test, 'NetAddr::IP');
ok(!$ip->network->contains($test), "!->contains");



