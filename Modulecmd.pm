# $Id: Modulecmd.pm,v 1.6 2001/07/09 20:51:40 ronisaac Exp $

# Copyright (c) 2001, Morgan Stanley Dean Witter and Co.
# Distributed under the terms of the GNU General Public License.
# Please see the copyright notice at the end of this file for more information.

package Env::Modulecmd;

use strict;
use Carp;
use vars qw($VERSION $AUTOLOAD);

use IPC::Open3;

$VERSION = 1.0;

my $modulecmd = $ENV{'PERL_MODULECMD'} || 'modulecmd';

sub import {
  my @args = @_;
  shift @args;

  # import just dispatches commands to _modulecmd

  foreach my $arg (@args) {
    if (ref ($arg) eq "HASH") {
      my %hash = %{$arg};
      foreach my $key (keys %hash) {
        my $val = $hash{$key};
        if (ref ($val) eq "ARRAY") {
          my @arr = @{$val};
          foreach my $module (@arr) {
            _modulecmd ($key, $module);
          }
        } else {
          _modulecmd ($key, $val);
        }
      }
    } else {
      _modulecmd ('load', $arg);
    }
  }
}

sub AUTOLOAD {
  my @modules = @_;

  # AUTOLOAD, like import, calls _modulecmd with the requested function

  my $fun = $AUTOLOAD;
  $fun =~ s/^.*:://;

  foreach my $module (@modules) {
    _modulecmd ($fun, $module);
  }
}

sub _indent {
  my ($str) = @_;

  $str =~ s/\n$//;
  $str =~ s/\n/\n -> /g;
  $str = " -> $str\n";

  return ($str);
}

sub _modulecmd {
  my ($fun, $module) = @_;

  # here's where the actual work gets done. first we build a command
  # string and send it to open3 for execution. we're not sending any
  # input, but we want to catch both its standard output and standard
  # error, so a simple piped open won't work.

  my $cmd = "$modulecmd perl $fun $module";
  open3 (\*IN, \*OUT, \*ERR, $cmd);

  close (IN);
  my $out = join ("", <OUT>);
  my $err = join ("", <ERR>);

  # if the process sent anything to standard error, assume that it failed

  if ($err) {

    # this is kind of messy... open3 does a fork and exec. if the exec
    # fails, open3 basically does this from the _child_ process: croak
    # "open3: exec of ... failed". croak adds on the caller's context,
    # writes this to standard error, and dies. we're catching the
    # child process's standard error, so we get this message in $err.
    # we want to display a meaningful error, but the caller's context
    # used by croak is _us_, and "at Modulecmd.pm line 77" is not
    # going to help anyone! so in this special case, we strip out only
    # the meaningful part of the error.

    my $file = __FILE__;
    if ($err =~ /^(.*) at $file line \d+/) {
      $err = $1;
    }

    # show the error message and die

    warn "Errors from '$cmd':\n";
    warn _indent ($err);
    croak "Error loading module $module";
  }

  # if we got here, then the command generated no errors. if it did
  # generate output, then we have something to eval.

  if ($out) {
    my $eval_err = "";
    my $stat;

    # what if we try to eval something that's not valid perl? in this
    # case, eval will die, with a message indicating what went wrong.
    # we want to catch this and nicely print out the error.

    {
      local $SIG{__WARN__} = sub { $eval_err .= $_[0]; };
      local $SIG{__DIE__} = sub { $eval_err .= $_[0]; };

      $stat = eval ($out);
    }

    unless ($stat) {
      warn "'$cmd' generated output:\n";
      warn _indent ($out);
      warn "Error evaluating:\n";
      warn _indent ($eval_err);
      croak "Error loading module $module";
    }
  }
}

1;

__END__

=head1 NAME

Env::Modulecmd - Interface to modulecmd from Perl

=head1 SYNOPSIS

  # import bootstraps, executed at compile-time

    # explicit operations

    use Env::Modulecmd { load => 'foo/1.0',
                         unload => ['bar/1.0', 'baz/1.0'],
                       };

    # implied loading

    use Env::Modulecmd qw(quux/1.0 quuux/1.0);

    # hybrid

    use Env::Modulecmd ('bazola/1.0', 'ztesch/1.0',
                        { load => 'oogle/1.0',
                          unload => [qw(foogle/1.0 boogle/1.0)],
                        }
                       );

  # implicit functions, executed at run-time

    Env::Modulecmd::load (qw(fred/1.0 jim/1.0 sheila/barney/1.0));
    Env::Modulecmd::unload ('corge/grault/1.0', 'flarp/1.0');
    Env::Modulecmd::pippo ('pluto/paperino/1.0');

=head1 DESCRIPTION

C<Env::Modulecmd> provides an automated interface to C<modulecmd> from
Perl. The most straightforward use of Env::Modulecmd is for loading
and unloading modules at compile time, although many other uses are
provided.

=head2 'modulecmd' Interface

In general, C<Env::Modulecmd> works by making a system call to
'C<modulecmd perl [cmd] [module]>', under the assumption that
C<modulecmd> is in your PATH. If you set the environment variable
C<PERL_MODULECMD>, C<Env::Modulecmd> will use that value in place of
C<modulecmd>. If C<modulecmd> is not found, the shell will return an
error and the script will die.

If C<modulecmd> outputs anything to standard error, it is assumed to
have failed. In this case, its error output is repeated on Perl's
standard error, and the script dies. Otherwise, C<modulecmd> is
assumed to have succeeded, and its output (if any) is C<eval>'ed.

If you attempt to load a module which has already been loaded, or
perform some other benign operation, C<modulecmd> will generate
neither output nor error; this condition is silently ignored.

=head2 Compile-Time Usage

You can specify compile-time arguments to C<Env::Modulecmd> on the
C<use> line, as follows:

  use Env::Modulecmd ('bazola/1.0', 'ztesch/1.0',
                      { load => 'oogle/1.0',
                        unload => [qw(foogle/1.0 boogle/1.0)],
                      }
                     );

Each argument is assumed to be either a scalar or a hashref. If it's a
scalar, C<Env::Modulecmd> assumes it's the name of a module you want
to load. If it's a hashref, then each key is the name of a modulecmd
operation (ie: C<load>, C<unload>) and each value is either a scalar
(operate on one module) or an arrayref (operate on several modules).

In the example given above, C<bazola/1.0> and C<ztesch/1.0> will be
loaded by implicit usage. C<oogle/1.0> will be loaded explicitly, and
C<foogle/1.0> and C<boogle/1.0> will be unloaded.

=head2 Run-Time Usage

Additional module operations can be performed at run-time by using
implicit functions. For example:

  Env::Modulecmd::load (qw(fred/1.0 jim/1.0 sheila/barney/1.0));
  Env::Modulecmd::unload ('corge/grault/1.0', 'flarp/1.0');
  Env::Modulecmd::pippo ('pluto/paperino/1.0');

Each function name is passed as a command name to C<modulecmd>, and
each call can include one or more modules to be processed. The example
above will generate the following six calls to C<modulecmd>:

  modulecmd perl load fred/1.0
  modulecmd perl load jim/1.0
  modulecmd perl load sheila/barney/1.0
  modulecmd perl unload corge/grault/1.0
  modulecmd perl unload flarp/1.0
  modulecmd perl pippo pluto/paperino/1.0

=head1 SEE ALSO

For more information about modules, see the F<module(1)> manpage or
F<http://www.modules.org>.

=head1 BUGS

If you find any bugs, or if you have any suggestions for improvement,
please contact the author.

=head1 AUTHOR

Ron Isaacson <F<Ron.Isaacson@morganstanley.com>>

=head1 COPYRIGHT

Copyright (c) 2001, Morgan Stanley Dean Witter and Co.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

A copy of the GNU General Public License was distributed with this
program in a file called LICENSE. For additional copies, write to the
Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
02111-1307, USA.

=cut
