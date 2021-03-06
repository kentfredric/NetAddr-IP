use ExtUtils::MakeMaker qw(
	WriteMakefile
	prompt
);
use Config;
use Cwd;
# fix for bug in Android's sh
use File::Spec;
use Getopt::Long qw(
	GetOptions
);

my $pwd = getcwd();

unlink 'Makefile';		# remove Makefile to stabilize CC test

#
# get any command line arguments
#
my($useXS);
GetOptions(
	'xs!'		=> \$useXS,
	'pm'		=> sub {
		warn "\n\t".'WARNING: Use of "--pm" is deprecated, use "-noxs" instead'."\n\n";
		$useXS = 0;
	},
);

print STDERR "building for $^O\n";

#if ($Config{osname} =~ /MSWin32/i || $Config{osname} eq 'dos') {
# kill windows and Darwin, both of which misbahave when building XS code
if ($Config{osname} =~ /win/i || $Config{osname} eq 'dos') {
  $useXS = 0;		# force NOXS mode for windows
}

my $pkg = 'NetAddr::IP::Util';
$pkg =~ /[^:]+$/;
my $module = $& .'.pm';
my $cfile = $& .'.c';

my %makeparms = (
    NAME		=> $pkg,
    VERSION_FROM	=> $module,	# finds $VERSION
#    depend		=> {$cfile => q[xs_include/miniSocket.inc localconf.h config.h localperl.h],
    depend		=> {$cfile => q[ localconf.h config.h localperl.h ],
			},
#    PREREQ_PM		=> { Socket6	=> 0.23,	can't do this
#			},
    LIBS		=> [],
    XS			=> {},
    C			=> [],
    clean		=> { FILES    => "*.bs *.o *.c *~ tmp* Util_IS.pm localperl.h auto*"},
    realclean		=> { FILES    => "config.h config.log config.status"},
    dist		=> {COMPRESS=>'gzip', SUFFIX=>'gz'}

);

#
# Check if we have a C compiler

unless (defined $useXS) {
  my $compiler = test_cc();
  if ($compiler) {
    $ENV{CC} = $compiler;
    print "You have a working compiler.\n";
    $useXS = 1;
#    $makeparms{'MYEXTLIB'} = 'netdns$(LIB_EXT)',

  } else {
    $useXS = 0;
    print <<END;

I cannot determine if you have a C compiler. I will install the
perl-only implementation.

You can force installation of the XS version with:

        perl Makefile.PL --xs
END

#    $makeparms{'MYEXTLIB'}    = '',
  }
}

my $begin = '';

while ($useXS) {
  # turn the XS bits on.
  delete $makeparms{'XS'};
  delete $makeparms{'C'};

# fix bug in Andorid's sh
  local $ENV{TMPDIR} = File::Spec->tmpdir() if $^O eq 'android';

  unless (-e './config.h') {
    system $Config{sh}, 'configure.gcc';
  }
  my @LIBS;
  unless (open(F,'config.h')) {
    warn "Cannot read config.h built by 'gcc', trying 'cc'.\n";
# try to build with cc
    system $Config(sh), 'configure.cc';
    unless (open(F,'config.h')) {
      warn "Cannot read config.h built by 'cc', using 'pure Perl'.\n";
      $useXS = 0;
      last;
    }
  }

  foreach(<F>) {
    if ($_ =~ /^#define LIBS([ a-zA-Z-]+)/) {
      @LIBS = ($1 =~ /[a-zA-Z0-9-]+/g);

      $makeparms{LIBS} = [$1];
      last;
    }
  }
  close F;
  my $link = '';
  foreach(@libs) {
    if ($Config{libs} =~ /$_\b/) {
      $link .= $_ .' ';
    }
  }
  chop $link;
  $makeparms{LIBS} = [$link];

  open(F,'>localperl.h') or die "could not open localperl.h for write\n";
  print F q|
/*	Written by Makefile.PL
 *
 *	Do not modify this file, modify Makefile.PL instead
 *
 */
|;
  close F;

  $begin = q|
config  :: config.h
	@$(NOOP)

config.h :
	$(SHELL) configure
|;
  last;
}

open(F,'>Util_IS.pm');
print F q|#!/usr/bin/perl
#
# DO NOT ALTER THIS FILE
# IT IS WRITTEN BY Makefile.PL
# EDIT THAT INSTEAD
#
package NetAddr::IP::Util_IS;
use vars qw($VERSION);
$VERSION = 1.00;


sub pure {
  return |, (($useXS) ? 0 : 1), q|;
}
sub not_pure {
  return |, (($useXS) ? 1 : 0), q|;
}
1;
__END__

=head1 NAME

NetAddr::IP::Util_IS - Tell about Pure Perl

=head1 SYNOPSIS

  use NetAddr::IP::Util_IS;

  $rv = NetAddr::IP::Util_IS->pure;
  $rv = NetAddr::IP::Util_IS->not_pure;

=head1 DESCRIPTION

Util_IS indicates whether or not B<NetAddr::IP::Util> was compiled in Pure
Perl mode.

=over 4

=item * $rv = NetAddr::IP::Util_IS->pure;

Returns true if PurePerl mode, else false.

=item * $rv = NetAddr::IP::Util_IS->not_pure;

Returns true if NOT PurePerl mode, else false

=back

=cut

1;
|;

sub test_cc {
  #
  # The perl/C check borrowed and modified from 
  # Graham Barr's Scalar-List-Utils distribution.
  #
  print "Testing if you have a C compiler and the needed header files....\n";

  unless (open(F, ">compile.c")) {
      warn "Cannot write compile.c, skipping test compilation and installing pure Perl version.\n";
    return 0;
  }

  my $CC;
  foreach $CC (($ENV{CC},$Config{cc},$Config{ccname})) {
    next unless $CC;
    my $command = qq|$CC compile.c -o compile.output|;

    print F <<'EOF';
int main() { return 0; }
EOF

    close(F) or return 0;

    print STDERR $command,"\n";

    my $rv = system($command);

    foreach my $file (glob('compile*')) {
      unlink($file) || warn "Could not delete $file: $!\n";
    }
    if ($rv == 0) {
      return $CC;
    }
  }
  return undef;
}

sub MY::top_targets {
  package MY;
  my $inherited = shift->SUPER::top_targets(@_);
  $inherited =~ s/(pure_all\s+::.+)/$1 README/;
  $begin . $inherited;
}

sub MY::post_constants {
  my $post_constants = $Config{scriptdirexp} .'/pod2text';
  if (-e $post_constants) {
    $post_constants = q|
MY_POD2TEXT = |. $post_constants .q|
|;
  } else {   
    $post_constants = q|
MY_POD2TEXT = echo "perl distro missing 'pod2text' to convert " |;
  }
}

sub MY::postamble {
  package MY;
  my $postamble = q|
README  : |. $module .q|
	@$(MY_POD2TEXT) |. $module .q| > README

|;
}

WriteMakefile(%makeparms);
