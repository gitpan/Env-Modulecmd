# $Id: test.pl,v 1.1 2001/06/04 18:42:50 ronisaac Exp $

# Copyright (c) 2001, Morgan Stanley Dean Witter and Co.
# Distributed under the terms of the GNU General Public License.
# Please see the copyright notice in Modulecmd.pm for more information.

use Test;
BEGIN {

  # prepare test plan

  plan tests => 2;

  # initialize environment

  $ENV{'MODULEPATH'} = '.' . ($ENV{'MODULEPATH'} ? ':' . $ENV{'MODULEPATH'} :
                              '');
};

# test loading

use Env::Modulecmd { load => 'testmod' };
ok ($ENV{'TESTMOD_LOADED'} eq "yes" ? 1 : 0);

# test unloading

Env::Modulecmd::unload ('testmod');
ok ($ENV{'TESTMOD_LOADED'} eq "yes" ? 0 : 2);
