##
## IP::Address - Help to work with IP addresses and masks
##
## lem@cantv.net - 19990712
##
## NAME CHANGE to NetAddr::IP (20000628 - lem@cantv.net)
##
##############
##############

package NetAddr::IP;

use strict;
use integer;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Use_CIDR_Notation 
	    $Always_Display_Mask);
use Carp;

use Math::BigInt;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = qw( $Use_CIDR_Notation $Always_Display_Mask
	
);

$VERSION = '2.00';


# Preloaded methods go here.

$Use_CIDR_Notation = 1;		# What notation is used to convert
				# addresses to their string representation
				# 1 means use CIDR notation (10.0.0.0/24)
				# 0 means use more traditional notation
				# like in 10.0.0.0/255.255.255.0
$Always_Display_Mask = 1;	# Wether to display redundant mask information
				# or not
sub _valid_address {
    my $ip = shift;
    ($ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/
     and $1 >= 0 and $1 <= 255
     and $2 >= 0 and $2 <= 255
     and $3 >= 0 and $3 <= 255
     and $4 >= 0 and $4 <= 255);
}

sub _pack_address {
    my $ip = shift;
    croak "attempt to pack invalid address $ip" 
	unless _valid_address $ip;
    my @octet = split(/\./, $ip, 4);
    my $result = '';
    my $octet = '';
    my $i; 
    my $j;
    foreach $j (0..3) {
	vec($octet, 0, 8) = $octet[$j];
	foreach $i (0 .. 7) {
	    vec($result, $i + 8 * $j, 1) = vec($octet, $i, 1);
	}
    }
    $result;
}

sub _unpack_address {
    my $pack = shift;
    my $i;
    my $j;
    my $result = '';
    foreach $j (0..3) {
	my $octet = '';
	foreach $i (0..7) {
	    vec($octet, $i, 1) = vec($pack, $i + 8 * $j, 1);
	}
	$result .= '.' if length $result;
	$result .= vec($octet, 0, 8);
    }
    $result;
}

sub _bits_to_mask {
    my $bits = shift;
#    croak "Invalid mask len $bits" if $bits < 0 or $bits > 32;
    my $i;
    my $j;
    my $count = 0;
    my $result = '';
    foreach $i (0..3) {
	foreach $j (reverse 0..7) {
	    vec($result, $i * 8 + $j, 1) = ($count++ < $bits);
	}
    }
    $result;
}

sub _mask_to_bits {
    my $mask = shift;
    my $i;
    my $result = 0;
    foreach $i (0..31) {
	my $bit = vec($mask, $i, 1);
#	croak "non-contiguous mask" if !$bit and $result;
	$result += $bit;
    }
    $result;
}

sub mask_bits {
    my $self = shift;
    return _mask_to_bits $self->{'mask'};
}

sub _negated_mask {
    my $mask = shift;
    my $nmask = '';
    my $i;
    my $pack = shift;
    foreach $i (0..31) {
	vec($nmask, $i, 1) = !vec($mask, $i, 1);
    }
    $nmask;
}

sub new {
    my $type = shift;
    my $class = ref($type) || $type || "NetAddr::IP";
    my ($ip, $mask) = @_;
    $ip = "0.0.0.0" unless defined $ip;
    if ($ip =~ /\/([\d\.]+)$/) {
#	croak "inconsistent mask. Use only one form of netmask"
	return undef if defined $mask;
	my $m = $1;
	$ip =~ s/\/\d+$//;
	$mask = $m;
    }
    $mask = "32" unless defined $mask; # Assume a host mask if none is given
    if ($mask =~ /\./) {
	$mask = _pack_address $mask;
    }
    else {
	return undef if ($mask < 0 or $mask > 32);
	$mask = _bits_to_mask $mask;
    }
    if (not _valid_address $ip) {
	return undef;
#	croak "invalid IP address";
    }
    my $self = { 'addr' => _pack_address($ip),
		 'mask' => $mask
		 };
    bless $self, $class;
}

sub new_subnet {
    my $ip = new @_;
    return undef unless $ip;
    my $subnet = $ip->network;
    if ($ip->addr_to_string eq $subnet->addr_to_string) {
	return $ip;
    }
    else {
	return undef;
    }
}

sub to_string {
    my $self = shift;
    my $addr = _unpack_address($self->{'addr'});
    my $mask = $Use_CIDR_Notation ? 
	_mask_to_bits($self->{'mask'}) 
	    : _unpack_address($self->{'mask'});
    my $wmask = _mask_to_bits($self->{'mask'});
    if (!$Always_Display_Mask and $wmask > 0 and
	(($wmask == 24 and $addr =~ /\.0$/ and $addr !~ /\.0\.0$/)
	 or ($wmask == 16 and $addr =~ /\.0\.0$/ and $addr !~ /\.0\.0\.0$/)
	 or ($wmask == 8 and $addr =~ /\.0\.0\.0$/ and 
	     $addr !~ /\.0\.0\.0\.0$/)
	 or ($wmask == 32 and $addr !~ /\.0$/))) {
	    $addr;
	}
	else {
	    $addr . "/" . $mask;
	}
}

sub mask_to_string {
    my $self = shift;
    $Use_CIDR_Notation ? 
	_mask_to_bits($self->{'mask'}) 
	    : _unpack_address($self->{'mask'});
}

sub addr_to_string {
    my $self = shift;
    _unpack_address($self->{'addr'});
}

sub host_enum {
    my $self = shift;
    my $first = vec($self->network->{'addr'}, 0, 32);
    my $last = vec($self->broadcast->{'addr'}, 0, 32);
    my $i;
    my @result;
    for($i = $first; $i <= $last; ++$i) {
	my $addr = '';
	vec($addr, 0, 32) = $i;
	push @result, $self->new(_unpack_address($addr), "32");
    }
    @result;
}

### XXX - We might need to return BigInts... Let's wait for testing in
### more platforms.

sub addr_number {
    my $self = shift;
#    return new Math::BigInt(vec($self->{'addr'}, 0, 32));
    return vec($self->{'addr'}, 0, 32);
}

sub _arrange_compact_list {
    my @addr = @_;
    @addr = sort {
  	new Math::BigInt(vec($a->{'mask'}, 0, 32)) 
  	    <=> new Math::BigInt(vec($b->{'mask'}, 0, 32))
	    } @addr;
    my @result;
    
  PROSPECT:
    foreach my $prospect (@addr) {
	foreach my $cur (@result) {
	    if ($cur->contains($prospect)) {
		next PROSPECT;
	    }
	}
	push @result, $prospect;
    }
    
    sort {
  	new Math::BigInt(vec($a->{'addr'}, 0, 32)) 
  	    <=> new Math::BigInt(vec($b->{'addr'}, 0, 32))
  	    } @result;
}

sub _can_split {
    my $a = shift;
    my $bits = shift;

    return ()			# $bits must make sense
	unless $bits > 0 and $bits < 31;

    my $m_len = _mask_to_bits($a->{'mask'});

    return ()			# Mask length must be < $bits
	unless  $m_len < $bits;

    $m_len ++;

    my $a1 = new NetAddr::IP(_unpack_address($a->network->{'addr'}) 
			     . "/" . $m_len);

    my $a2 = new NetAddr::IP(_unpack_address($a->broadcast->{'addr'}) 
			     . "/" . $m_len)->network;

    if ($m_len == $bits) {
	return ($a1, $a2);
    }
    
    return (_can_split($a1, $bits), _can_split($a2, $bits));

}

sub _can_merge {
    my $a = shift;
    my $b = shift;
    my $bits = shift;

    return 0			# Masks must be equal
	unless vec($a->{'mask'}, 0, 32) == vec($b->{'mask'}, 0, 32);

    return 0			# Mask lenght must be > 0
	if _mask_to_bits($a->{'mask'}) == 0;

    return 0			# Mask length must be >= $bits
	if _mask_to_bits($a->{'mask'}) < $bits;
    
    my $masklen = _mask_to_bits($a->{'mask'}) - 1;
    my $container = new NetAddr::IP 
	_unpack_address($a->{'addr'}) . "/" 
	    . $masklen;

    return 0			# Both must be contained in the same
				# supernet
	unless $container->contains($a)
	    and $container->contains($b);

    $container;
}

sub expand {
    my $bits = shift;
    my @addr = @_;

    if (@addr == 1 and scalar $addr[0]) {
	my $b = $bits;
	$bits = $addr[0];
	$addr[0] = $b;
    }

    @addr = _arrange_compact_list(@addr);
    my $changes = 1;

    if (_valid_address $bits) {
	$bits = _mask_to_bits _pack_address $bits;
    }

    croak "Invalid bit length ($bits)" if $bits < 0 or $bits > 32;

    my $a;
    my $b;

    while ($changes) {
	$changes = 0;

	for (my $i = 0; $i <= $#addr; $i++) {
	    $a = $addr[$i];

	    if (my @subnets = _can_split $a, $bits) {

		@addr = (@addr[0 .. $i - 1], 
			 @subnets, 
			 @addr[$i + 1 .. $#addr]);

		$i += $#subnets;
		next;
	    } 

	    $b = $addr[$i + 1];
	    if (my $container = _can_merge $a, $b, $bits) {
		$addr[$i] = $container;
		$changes = 1;
		next;
	    }
	}
	@addr = _arrange_compact_list(@addr) if $changes;
    }
    return @addr;
    
}

sub compact {
    my @addr = _arrange_compact_list(@_);
    my $changes = 1;

    my $a;
    my $b;

    while ($changes) {
	$changes = 0;
	for (my $i = 0; $i < $#addr; $i++) {
	    $a = $addr[$i];
	    $b = $addr[$i + 1];
	    if (my $container = _can_merge $a, $b, 0) {
		$addr[$i] = $container;
		$changes = 1;
		next;
	    }
	}
	@addr = _arrange_compact_list(@addr) if $changes;
    }
    return @addr;
}

sub enum {
    my $self = shift;
    my $first = vec($self->network->{'addr'}, 0, 32);
    my $last = vec($self->broadcast->{'addr'}, 0, 32);
    my $i;
    my @result;
    for($i = $first; $i <= $last; ++$i) {
	my $addr = '';
	vec($addr, 0, 32) = $i;
	push @result, $self->new(_unpack_address($addr), 
				 _unpack_address($self->{'mask'}));
    }
    @result;
}

sub network {
    my $self = shift;
    $self->new (_unpack_address($self->{'addr'} & $self->{'mask'}), 
		_unpack_address($self->{'mask'}));
}

sub first {
    my $self = shift;
    my $addr = '';
    return $self if (_mask_to_bits($self->{'mask'}) == 32);
    my $subnet = $self->new (_unpack_address($self->{'addr'} 
					     & $self->{'mask'}), 
		_unpack_address($self->{'mask'}));
    vec($addr, 0, 32) = vec($subnet->{'addr'}, 0, 32) + 1;
    $self->new (_unpack_address($addr), 
		_unpack_address($self->{'mask'}));
}

sub broadcast {
    my $self = shift;
    $self->new (_unpack_address($self->{'addr'} 
				| _negated_mask $self->{'mask'}),
		_unpack_address($self->{'mask'}));
}

sub last {
    my $self = shift;
    my $addr = '';
    return $self if (_mask_to_bits($self->{'mask'}) == 32);
    my $subnet = $self->new (_unpack_address($self->{'addr'} 
					     | _negated_mask $self->{'mask'}),
		_unpack_address($self->{'mask'}));
    vec($addr, 0, 32) = vec($subnet->{'addr'}, 0, 32) - 1;
    $self->new (_unpack_address($addr), 
		_unpack_address($self->{'mask'}));
}

sub range {
    my $self = $_[0];
    my $ip;
    my $min = $self->new("255.255.255.255");
    my $max = $self->new("0.0.0.0");
    $max->set_addr($self);

    foreach $ip (@_) {

				# This comparison is very tricky in some
				# architectures, so we might make it in 
				# BigInts to be safe. - XXXX

  	my $bi_ipn = new Math::BigInt vec($ip->network->{'addr'}, 0, 32);
  	my $bi_ipb = new Math::BigInt vec($ip->broadcast->{'addr'}, 0, 32);
  	my $bi_min = new Math::BigInt vec($min->{'addr'}, 0, 32);
  	my $bi_max = new Math::BigInt vec($max->{'addr'}, 0, 32);

	if ($bi_ipn - $bi_min < 0) {
	    $min->set_addr($ip->network);
	}
	if ($bi_ipb - $bi_max > 0) {
	    $max->set_addr($ip->broadcast);
	}
    }

    my @result;
    for($ip = vec($min->{'addr'}, 0, 32); 
	$ip <= vec($max->{'addr'}, 0, 32);
	++$ip) {
	my $addr = '';
	vec($addr, 0, 32) = $ip;
	push @result, $self->new(_unpack_address($addr), "32");
    }
    @result;
}

sub set_mask {
    my $self = shift;
    my $other = shift;
    $self->{'mask'} = $other->{'mask'};
    $self;
}

sub set_addr {
    my $self = shift;
    my $other = shift;
    $self->{'addr'} = $other->{'addr'};
    $self;
}

sub how_many {
    my $self = shift;
    vec($self->broadcast->{'addr'}, 0, 32) - 
	vec($self->network->{'addr'}, 0, 32) + 1;
}

sub contains {
    my $self = shift;
    my $other = shift;
    my $self_min = new Math::BigInt vec($self->network->{'addr'}, 0, 32);
    my $self_max = new Math::BigInt vec($self->broadcast->{'addr'}, 0, 32);
    my $other_min = new Math::BigInt vec($other->network->{'addr'}, 0, 32);
    my $other_max = new Math::BigInt vec($other->broadcast->{'addr'}, 0, 32);
    $other_min >= $self_min and $other_min <= $self_max
	and $other_max >= $self_min and $other_max <= $self_max;
}

1;
__END__

=head1 NAME

NetAddr::IP - Manipulate IP Addresses easily

=head1 SYNOPSIS

  use NetAddr::IP qw($Use_CIDR_Notation $Always_Display_Mask);

  # Initialization of NetAddr::IP objects
  my $ip = new NetAddr::IP "10.0.0.1";
  my $subnet = new NetAddr::IP("10.0.0.0", "255.255.255.0");
  my $othersubnet = new NetAddr::IP("10.0.0.0", "24");
  my $yetanothersubnet = new NetAddr::IP "10.0.0.0/24";

  # A proper subnet (or undef if any host but is set)
  my $subnet_ok = new_subnet NetAddr::IP("10.0.0.0", "24");
  my $subnet_undef = new_subnet NetAddr::IP("10.0.0.1", "24");

  # A string representation of an address or subnet
  print "My ip address is ", $ip->to_string, "\n";

  # Just the string or the mask part...
  print "My ip address alone is ", $ip->addr_to_string, "\n";
  print "and my netmask is ", $ip->mask_to_string, "\n";

  # Enumeration of all the addresses within a given subnet, keeping
  # the original mask
  my @hosts = $subnet->enum;
  for $i (@hosts) {
      print "address ", $i->to_string, 
      " belongs to subnet ", $subnet->to_string, "\n";
  }

  # You can also produce the list of host addresses in a given subnet
  my @hosts = $subnet->host_enum;
  for $i (@hosts) {
      print "Host ", $i->to_string, 
      " is in subnet ", $subnet->to_string, "\n";
  }

  # This calculates network and broadcast addresses for a subnet
  my $network = $subnet->network;
  my $broadcast = $subnet->broadcast;
  print "Subnet ", $subnet->to_string, " has broadcast address ",
    $broadcast->to_string, " and network number ", $network->to_string,
    "\n";

  # Checks to see if a host address or subnet is contained within another
  # subnet
  if ($subnet->contains $ip) {
      print "Host ", $ip->to_string, " is contained in ",
      $subnet->to_string, "\n";
  }

  # Masks and address components can be copied from object to object
  $ip1->set_addr($ip2);
  $ip1->set_mask($subnet);

  # Ammount of hosts in a subnet can also be easily calculated
  $max_hosts_in_subnet = $subnet->how_many - 2;

  # A range of IP Addresses
  @range = $ip->range($final_ip); # From $ip to $final_ip
  @range = $ip->range(@dont_know_which_is_larger);
				# From the smallest on the list + $ip to
				# the largest

  # Usable addresses in a subnet
  $first_address = $subnet->first;
  $last_address = $subnet->last;

  # Compact subnets or addresses into the largest possible CIDR block
  @compact_block = NetAddr::IP::compact(@many_small_ip_address_blocks);

  # Split a set of blocks into smaller subnets
  @small_subnets = NetAddr::IP::expand(@ip_address_blocks);

  # Obtain a numeric representation of an IP address
  my $number = $ip->addr_number;

  # How many bits are there in the mask?
  my $masklen = $ip->mask_bits;

=head1 DESCRIPTION

This module provides a simple interface to the tedious bit manipulation
involved when handling IP address calculations. It also helps by performing
range comparisons between subnets as well as other frequently used functions.

Most of the primitive functions return a NetAddr::IP object.

The variables 
B<$Use_CIDR_Notation>
 and 
B<$Always_Display_Mask>
 affect how the
->to_string function will present its result. The names are hopefully 
intuitive enough. Note that IP addresses are not properly compacted
(ie, 200.44.0/18 is written as 200.44.0.0/18) because this adapts to 
the widely adopted but incorrect notation. Perhaps a later version will
include a variable to change this.

This code has not been widely tested yet. Endianness problems might very
well exist. Please email the author if such problems are found.

This software is (c) Luis E. Munoz. It can be used under the terms of the
perl artistic license provided that proper credit is preserved and that
the original documentation is not removed.

This software comes with the same warranty as perl itself (ie, none), so
by using it you accept any and all the liability.

=head1 AUTHOR

Luis E. Munoz <lem@cantv.net>

=head1 SEE ALSO

perl(1).

=cut

    1;
