# $Id: test.pl,v 4.1 2004/06/09 13:32:26 ronisaac Exp $

# Copyright (c) 2001-2003, Morgan Stanley Dean Witter and Co.
# Distributed under the terms of the GNU General Public License.
# Please see the copyright notice in Modulecmd.pm for more information.

use Test;
use Env::Modulecmd;

BEGIN {
  # prepare test plan

  plan tests => 3;
}

# initialize environment

eval { Env::Modulecmd::use ('.'); };

if ($@ =~ /open3: exec of .* failed/) {
  die <<MSG;

  ***** ERROR *****

  Env::Modulecmd was not able to invoke 'modulecmd'. This means
  one of two things:

  1. You do not have the 'modules' package installed. See
     http://www.modules.org for more information about this
     package. If you don't have it, Env::Modulecmd is probably
     not of any use to you.

  2. You do have the 'modules' package installed, but
     Env::Modulecmd was not able to find 'modulecmd'. There
     are three ways to correct this problem:

       a. Put 'modulecmd' in your PATH
       b. Set the environment variable PERL_MODULECMD to the full
          path to 'modulecmd'
       c. Rebuild the Env::Modulecmd package with a default
          PERL_MODULECMD; see the README for more information

MSG
}

die $@ if $@;
ok (1);

# test loading

Env::Modulecmd::load ('testmod');
ok ($ENV{'TESTMOD_LOADED'} eq "yes" ? 2 : 0);

# test unloading

Env::Modulecmd::unload ('testmod');
ok ($ENV{'TESTMOD_LOADED'} eq "yes" ? 0 : 3);
