use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# $Id: Makefile.PL,v 1.3 2002/12/10 17:14:02 lem Exp $

WriteMakefile(
    'NAME'		=> 'NetAddr::IP',
    'VERSION_FROM'	=> 'IP.pm', # finds $VERSION
    'PREREQ_PM'		=> {
      Test::More => 0,
    }, # e.g., Module::Name => 1.1
	      ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
	       (ABSTRACT_FROM	=> 'IP.pm',
		AUTHOR     	=> 'Luis E. Muñoz <luismunoz@cpan.org>') : ()),
);
