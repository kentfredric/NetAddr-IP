use NetAddr::IP;

$| = 1;

print "1..50\n";

my $count = 1;

for my $bits (8 .. 32) {
    my $large = new NetAddr::IP '10.0.0.0/8';
    my $small = new NetAddr::IP '10.0.0.0', $bits;

    my @c = NetAddr::IP::compact($large, $small);

    if (@c == 1) {
	print "ok $count\n";
    }
    else {
	print "not ok $count\n";
    }

    ++$count;

    if ($c[0]->cidr eq '10.0.0.0/8') {
	print "ok $count\n";
    }
    else {
	print "not ok $count\n";
    }

    ++$count;
}

