package Rose::DateTime::Util;

use strict;

use Carp();

use DateTime;
use DateTime::Infinite;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(format_date parse_date parse_european_date);

our %EXPORT_TAGS =
(
  std => [ qw(format_date parse_date parse_european_date) ],
  all => \@EXPORT_OK
);

our $VERSION = '0.50';

our $TZ = 'floating';
our $Debug = 0;
our $European_Dates = 0;
our $Error;

sub error { $Error }

sub time_zone
{
  my($class) = shift;
  return $TZ = shift  if(@_);
  return $TZ;
}

sub european_dates
{
  my($class) = shift;
  return $European_Dates = $_[0] ? 1 : 0  if(@_);
  return $European_Dates;
}

sub parse_european_date
{
  local $European_Dates = 1;
  &parse_date; # implicitly pass the current args: @_
}

sub parse_date
{
  my($arg, $time_zone) = @_;

  $time_zone ||= $TZ;

  my($fsecs, $secs, $mins, $hours, $mday, $month, $year, $wday, $yday, $isdst,
     $month_abbrev, $date, $ampm);

  $Error = undef;

  if(ref $arg && $arg->isa('DateTime'))
  {
    if(@_ > 1)
    {
      eval { $arg->set_time_zone($time_zone) };

      if($@)
      {
        $Error = $@;
        return undef;
      }
    }

    return $arg;
  }
  elsif(($year, $month, $mday, $hours, $mins, $secs, $fsecs, $ampm) =
       ($arg =~ /^(\d{4})\s*-?\s*(\d{2})\s*-?\s*(\d{2})(?:\s*-?\s*(\d\d?)(?::(\d\d)(?::(\d\d))?)?(?:\.(\d{0,9}))?(?:\s*([aApP]\.?[mM]\.?))?)?$/))
  {
    # yyyy mm dd [hh:mm[:ss[.nnnnnnnnn]]] [am/pm] also valid w/o spaces or w/ hyphens

    $date = _timelocal($secs, $mins, $hours, $mday, $month, $year, $ampm, $fsecs, $time_zone);
  }
  elsif(($month, $mday, $year, $hours, $mins, $secs, $fsecs, $ampm) = 
        ($arg =~ m#^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:\s+(\d\d?)(?::(\d\d)(?::(\d\d))?)?(?:\.(\d{0,9}))?(?:\s*([aApP]\.?[mM]\.?))?)?$#))
  {
    # Normal:   mm/dd/yyyy, mm-dd-yyyy, mm.dd.yyyy [hh:mm[:ss][.nnnnnnnnn]] [am/pm]
    # European: dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy [hh:mm[:ss][.nnnnnnnnn]] [am/pm]

    if($European_Dates)
    {
      ($mday, $month) = ($month, $mday); # swap month and day in Euro-mode
    }

    $date = _timelocal($secs, $mins, $hours, $mday, $month, $year, $ampm, $fsecs, $time_zone);
  }
  elsif($arg =~ /^now$/i)
  {
    # Right now
    return DateTime->now(time_zone => $time_zone);
  }
  elsif($arg =~ /^(\d{9,10})(?:\.(\d{0,9}))?$/)
  {
    # In Unix time format (guessing)
    $date = DateTime->from_epoch(epoch => $1, time_zone => $time_zone);

    if(my $fsecs = $2)
    {
      my $len = length $fsecs;

      if($len < 9)
      {
        $fsecs .= ('0' x (9 - length $fsecs));
      }
      elsif($len > 9)
      {
        $fsecs = substr($fsecs, 0, 9);
      }

      $date->set(nanosecond => $fsecs);
    }

    return $date;
  }
  elsif($arg =~ /^today$/i)
  {
    $date = DateTime->now(time_zone => $time_zone);
    $date->hour(0);
    $date->minute(0);
    $date->second(0);
  }

  elsif($arg =~ /^(-)?infinity$/i)
  {
    if($1)
    {
      return DateTime::Infinite::Past->new;
    }

    return DateTime::Infinite::Future->new;
  }
  else
  {
    $Error = "Could not parse date: $arg" .
             (($Error) ? " - $Error" : '');
    return undef;
  }

  unless($date)
  {
    $Error = "Could not parse date: $arg" .
             (($Error) ? " - $Error" : '');
    return undef;
  }

  return $date;
}

sub format_date
{
  my($date, @formats) = @_;

  my(@localtime, %formats, @ret, $ret);

  return undef  unless(defined $date);
  #return $date  if($date =~ /^-?infinity$/i);

  unless(ref $date && $date->isa('DateTime'))
  {
    Carp::croak("format_date() requires a DateTime object as its first argument");
  }

  return '-infinity'  if($date->isa('DateTime::Infinite::Past'));
  return 'infinity'   if($date->isa('DateTime::Infinite::Future'));

  foreach my $format (@formats)
  {
    $format =~ s/%t/%l:%M:%S %p/g; # strftime() treats %t as a \t

    # Formats not handled by strftime()
    if($format =~ /%[EFf]/)
    {
      unless(%formats)
      {
        my $date_word;
        my $mday = $date->day;

        #if($mday =~ /([^1]|^)1$/)    { $date_word = $mday . 'st' }
        #elsif($mday =~ /([^1]|^)2$/) { $date_word = $mday . 'nd' }
        #elsif($mday =~ /([^1]|^)3$/) { $date_word = $mday . 'rd' }
        #else                         { $date_word = $mday . 'th' }

        # Requires a reasonably modern perl
        if($mday =~ /(?<!1)1$/)    { $date_word = $mday . 'st' }
        elsif($mday =~ /(?<!1)2$/) { $date_word = $mday . 'nd' }
        elsif($mday =~ /(?<!1)3$/) { $date_word = $mday . 'rd' }
        else                       { $date_word = $mday . 'th' }

        %formats =
        (
          #'%e' => $mday, # DateTime snagged  this one
          '%E' => $date_word,
          '%F' => $date->strftime("%A, %B $date_word %Y"),
          '%f' => $date->month + 0,
        );
      }

      $format =~ s/(%[eEFf])/$formats{$1}/g;
    }

    push(@ret, $date->strftime($format));
  }

  return wantarray ? @ret : join(' ', @ret);
}

#
# Internal Subroutines
#

sub _timelocal
{
  my($secs, $mins, $hours, $mday, $month, $year, $ampm, $fsecs, $tz) = @_;

  my($date);

  $hours  = 0  unless(defined($hours));

  if(defined $fsecs)
  {
    my $len = length $fsecs;

    if($len < 9)
    {
      $fsecs .= ('0' x (9 - length $fsecs));
    }
    elsif($len > 9)
    {
      $fsecs = substr($fsecs, 0, 9);
    }
  }
  else
  {
    $fsecs = 0;
  }

  $secs  = 0  unless(defined $secs);
  $mins  = 0  unless(defined $mins);

  if($ampm)
  {
    if($ampm =~ /^p/i)
    {
      $hours += 12  unless($hours == 12);
    }
    elsif($hours == 12)
    {
      $hours = 0;
    }
  }

  eval
  {
    $date = DateTime->new(year   => $year,
                          month  => $month,
                          day    => $mday,
                          hour   => $hours,
                          minute => $mins,
                          second => $secs,
                          nanosecond => $fsecs,
                          time_zone => $tz);
  };

  if($@)
  {
    $Error = $@;
    warn $Error  if($Debug); # $ENV{'MOD_PERL'}
    return;
  }

  return $date;
}

1;

# Can't figure out how to hide comments like this from search.cpan.org's
# POD-to-HTML translator...
# =begin comment
# B<PLEASE NOTE:> The local time zone may not be known on all systems (in
# particular, Win32 systems).  If you are on such a system, you will encounter a
# fatal error if C<parse_date()> tries to construct a L<DateTime> object with
# a time zone of "local".
# 
# See the L<DateTime::TimeZone> documentation for information on the various
# ways to successfully indicate your local time zone, or set a different default
# time zone for this class by calling
# L<Rose::DateTime::Util-E<gt>time_zone(...)> with a new time zone as an
# argument.
# =end comment

__END__

=head1 NAME

Rose::DateTime::Util - Some simple DateTime wrapper functions.

=head1 SYNOPSIS

    use Rose::DateTime::Util qw(:all);

    $now  = parse_date('now');
    $then = parse_date('12/25/2001 11pm');

    print $now->day_of_week; # e.g., "Monday"

    # "December 25th 2001 at 11:00:00 PM"
    $date_text = format_date($then, "%B %E %Y at %t");

=head1 DESCRIPTION

L<Rose::DateTime::Util> is a thin wrapper around L<DateTime> that provides a very simple date parser and a few extra date formatting options.

=head1 EXPORTS

L<Rose::DateTime::Util> does not export any function names by default.

The 'all' tag:

    use Rose::DateTime::Util qw(:all);

will cause the following function names to be imported:

    format_date()
    parse_date()
    parse_european_date()

=head1 CLASS METHODS

=over 4

=item B<error>

Returns a message describing the last error that occurred.

=item B<european_dates [BOOL]>

Get or set a boolean flag that determines how "xx/xx/xxxx" dates are parsed by the L<parse_date|/parse_date> function.  If set to false, then such dates are parsed as "mm/dd/yyyy".  (This is the default.)  If set to true, then they're parsed as "dd/mm/yyyy".

=item B<time_zone [TZ]>

Get or set the default time zone.  This value is passed to L<DateTime-E<gt>new(...)|DateTime> as the value of the C<time_zone> parameter when L<parse_date()|/parse_date> creates the L<DateTime> object that it returns. The default value is "floating".

=back

=head1 FUNCTIONS

=over 4

=item B<format_date DATETIME, FORMAT1, FORMAT2 ...>

Takes a L<DateTime> object and a list of format strings.  In list context, it returns a list of strings with the formats interpolated.  In scalar context, it returns a single string constructed by joining all of the list-context return values with single spaces.  Examples:

  # $s = 'Friday 5PM' 
  $s = format_date(parse_date('1/23/2004 17:00'), '%A, %I%p');

  # @s = ('Friday', 5, 'PM')
  @s = format_date(parse_date('1/23/2004 17:00'), '%A', '%I', '%p');

  # $s = 'Friday 5 PM' 
  $s = format_date(parse_date('1/23/2004 17:00'), '%A', '%I', '%p');

Returns undef on failure, or if passed an undefined value for DATETIME.  An exception will be raised if the DATETIME argument is defined, but is not a L<DateTime> object.

The supported formats are mostly based on those supported by L<DateTime>'s C<strftime()> method.  L<Rose::DateTime::Util> calls L<DateTime>'s C<strftime()> method when interpolating these formats.

Note that the C<%t> and C<%F> formats are I<not> passed to C<strftime()>, but are handled by L<Rose::DateTime::Util> instead.  See the "Non-standard formats" section below.

The C<strftime()>-compatible formats listed below have been transcribed from the L<DateTime> documentation for the sake of convenience, but the L<DateTime> documentation is the definitive source.

Using any format strings not in the C<strftime()>-compatible set will be slightly slower.

B<C<strftime()>-compatible formats>

=over 4

=item * %a

The abbreviated weekday name.

=item * %A

The full weekday name.

=item * %b

The abbreviated month name.

=item * %B

The full month name.

=item * %c

The default datetime format for the object's locale.

=item * %C

The century number (year/100) as a 2-digit integer.

=item * %d

The day of the month as a decimal number (range 01 to 31).

=item * %D

Equivalent to %m/%d/%y.  This is not a good standard format if you have want both Americans and Europeans to understand the date!

=item * %e

Like %d, the day of the month as a decimal number, but a leading zero is replaced by a space.

=item * %G

The ISO 8601 year with century as a decimal number.  The 4-digit year corresponding to the ISO week number (see %V).  This has the same format and value as %y, except that if the ISO week number belongs to the previous or next year, that year is used instead. (TZ)

=item * %g

Like %G, but without century, i.e., with a 2-digit year (00-99).

=item * %h

Equivalent to %b.

=item * %H

The hour as a decimal number using a 24-hour clock (range 00 to 23).

=item * %I

The hour as a decimal number using a 12-hour clock (range 01 to 12).

=item * %j

The day of the year as a decimal number (range 001 to 366).

=item * %k

The hour (24-hour clock) as a decimal number (range 0 to 23); single digits are preceded by a blank. (See also %H.)

=item * %l

The hour (12-hour clock) as a decimal number (range 1 to 12); single digits are preceded by a blank. (See also %I.)

=item * %m

The month as a decimal number (range 01 to 12).

=item * %M

The minute as a decimal number (range 00 to 59).

=item * %n

A newline character.

=item * %N

The fractional seconds digits. Default is 9 digits (nanoseconds).

  %3N   milliseconds (3 digits)
  %6N   microseconds (6 digits)
  %9N   nanoseconds  (9 digits)

=item * %p

Either `AM' or `PM' according to the given time value, or the corresponding strings for the current locale.  Noon is treated as `pm' and midnight as `am'.

=item * %P

Like %p but in lowercase: `am' or `pm' or a corresponding string for the current locale.

=item * %r

The time in a.m.  or p.m. notation.  In the POSIX locale this is equivalent to `%I:%M:%S %p'.

=item * %R

The time in 24-hour notation (%H:%M). (SU) For a version including the seconds, see %T below.

=item * %s

The number of seconds since the epoch.

=item * %S

The second as a decimal number (range 00 to 61).

=item * %T

The time in 24-hour notation (%H:%M:%S).

=item * %u

The day of the week as a decimal, range 1 to 7, Monday being 1.  See also %w.

=item * %U

The week number of the current year as a decimal number, range 00 to 53, starting with the first Sunday as the first day of week 01. See also %V and %W.

=item * %V

The ISO 8601:1988 week number of the current year as a decimal number, range 01 to 53, where week 1 is the first week that has at least 4 days in the current year, and with Monday as the first day of the week. See also %U and %W.

=item * %w

The day of the week as a decimal, range 0 to 6, Sunday being 0.  See also %u.

=item * %W

The week number of the current year as a decimal number, range 00 to 53, starting with the first Monday as the first day of week 01.

=item * %x

The default date format for the object's locale.

=item * %X

The default time format for the object's locale.

=item * %y

The year as a decimal number without a century (range 00 to 99).

=item * %Y

The year as a decimal number including the century.

=item * %z

The time-zone as hour offset from UTC.  Required to emit RFC822-conformant dates (using "%a, %d %b %Y %H:%M:%S %z").

=item * %Z

The time zone or name or abbreviation.

=item * %%

A literal `%' character.

=item * %{method}

Any method name may be specified using the format C<%{method}> name where "method" is a valid C<DateTime.pm> object method.

=back

B<Non-standard formats>

=over 4

=item * %E

Day of the month word (1st, 2nd, 3rd, ... 31st)

=item * %f

Month number (1, 2, 3, ... 12)

=item * %F

"%A, %B %E %Y" (Wednesday, April 4th 2001)

=item * %i

Hour, 12-hour (1, 2, 3, ... 12)

=item * %t

Time as "%l:%M:%S %p" (1:23:45 PM)

=back

=item B<parse_european_date TEXT [, TIMEZONE]>

This function works the same as the L<parse_date|/parse_date> function, except it forces L<Eurpoean-style|european_dates> date parsing.  In other words, this:

    parse_european_date($date, $tz);

is equivalent to this:

    # Save old value of the European date setting
    my $save = Rose::DateTime::Util->european_dates;

    # Turn European date parsing on
    Rose::DateTime::Util->european_dates(1);

    # Parse the date
    parse_date($date, $tz);

    # Restore the old European date setting
    Rose::DateTime::Util->european_dates($save);

=item B<parse_date TEXT [, TIMEZONE]>

Attempts to parse the date described by TEXT.  Returns a L<DateTime> object, or undef on failure, with an error message available via C<Rose::DateTime::Util-E<gt>error()|/error>.

If a L<DateTime> object is passed in place of the TEXT argument, it is returned as-is if there is no TIMEZONE argument, or after having L<set_time_zone(TIMEZONE)|DateTime/set_time_zone> called on it if there is a TIMEZONE argument.

Since the time zone is not part of any of the supported date string formats, L<parse_date()|/parse_date> takes an optional TIMEZONE argument which is passed to the L<DateTime> constructor as the value of the C<time_zone> parameter.  In the absence of a TIMEZONE argument to C<parwse_date()>, the time zone defaults to the value returned by the L<time_zone()|/time_zone> class method ("floating", by default)

The formats understood and their interpretations are listed below.  Square brackets are used to undicate optional portions of the formats.

=over 4

=item now

Right now.

=item today

Today, at 00:00:00.

=item yyyy mm dd [hh:mm[:ss[.nnnnnnnnn]]] [am/pm]

Exact date and time.  Also valid without spaces and with hyphens between the year, month, day, and time.  The time is optional and defaults to 00:00:00. Fractional seconds take a maximum of 9 digits, but fewer are also acceptable.

=item mm/dd/yyyy [hh:mm[:ss[.nnnnnnnnn]]] [am/pm]

Exact date and time.  Also valid with hyphens ("-") or dots (".") instead of slashes ("/").  The time is optional and defaults to 00:00:00.  Fractional seconds take a maximum of 9 digits, but fewer are also acceptable.

This format is only valid when L<european_dates|/european_dates> is set to B<false> (which is the default).

=item dd/mm/yyyy [hh:mm[:ss[.nnnnnnnnn]]] [am/pm]

Exact date and time.  Also valid with hyphens ("-") or dots (".") instead of slashes ("/").  The time is optional and defaults to 00:00:00.  Fractional seconds take a maximum of 9 digits, but fewer are also acceptable.

This format is only valid when L<european_dates|/european_dates> is set to B<true>.

=item [-]infinity

Positive or negative infinity.  Case insensitive.

=item (string of 9 or more digits)

Interpreted as seconds since the Unix epoch.

=back

=back

=head1 SEE ALSO

L<DateTime>, L<DateTime::TimeZone>

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2004-2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
