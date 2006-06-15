package Time::Clock;

use strict;

use Carp;

our $VERSION = '0.10';

use overload
(
  '""' => sub { shift->as_string },
   fallback => 1,
);

use constant NANOSECONDS_IN_A_SECOND => 1_000_000_000;
use constant SECONDS_IN_A_MINUTE     => 60;
use constant SECONDS_IN_AN_HOUR      => SECONDS_IN_A_MINUTE * 60;
use constant SECONDS_IN_A_CLOCK      => SECONDS_IN_AN_HOUR * 24;

use constant DEFAULT_FORMAT => '%H:%M:%S%n';

our %Default_Format;

__PACKAGE__->default_format(DEFAULT_FORMAT);

sub default_format
{
  my($invocant) = shift;
  
  # Called as object method
  if(ref $invocant)
  {
    return $invocant->{'default_format'} = shift  if(@_);
    return ref($invocant)->default_format;
  }

  # Called as class method
  return $Default_Format{$invocant} = shift  if(@_);
  return $Default_Format{$invocant} ||= DEFAULT_FORMAT;
}

sub new
{
  my($class) = shift;

  my $self = bless {}, $class;
  @_ = (parse => @_)  if(@_ == 1);
  $self->init(@_);

  return $self;
}

sub init
{
  my($self) = shift;

  while(@_)
  {
    my $method = shift;
    $self->$method(shift);
  }
}

sub hour
{
  my($self) = shift;
  
  if(@_)
  {
    my $hour = shift;

    croak "hour must be between 0 and 23"  
      unless(!defined $hour || ($hour >= 0 && $hour <= 23));

    return $self->{'hour'} = $hour;
  }

  return $self->{'hour'} ||= 0;
}

sub minute
{
  my($self) = shift;
  
  if(@_)
  {
    my $minute = shift;

    croak "minute must be between 0 and 59"  
      unless(!defined $minute || ($minute >= 0 && $minute <= 59));

    return $self->{'minute'} = $minute;
  }

  return $self->{'minute'} ||= 0;
}

sub second
{
  my($self) = shift;
  
  if(@_)
  {
    my $second = shift;

    croak "second must be between 0 and 59"  
      unless(!defined $second || ($second >= 0 && $second <= 59));

    return $self->{'second'} = $second;
  }

  return $self->{'second'} ||= 0;
}

sub nanosecond
{
  my($self) = shift;
  
  if(@_)
  {
    my $nanosecond = shift;

    croak "nanosecond must be between 0 and ", (NANOSECONDS_IN_A_SECOND - 1)
      unless(!defined $nanosecond || ($nanosecond >= 0 && $nanosecond < NANOSECONDS_IN_A_SECOND));

    return $self->{'nanosecond'} = $nanosecond;
  }

  return $self->{'nanosecond'};
}

sub ampm
{
  my($self) = shift;
  
  if(@_ && defined $_[0])
  {
    my $ampm = shift;

    if($ampm =~ /^a\.?m\.?$/i)
    {
      if($self->hour > 12)
      {
        croak "Cannot set AM/PM to AM when hour is set to ", $self->hour;
      }
      elsif($self->hour == 12)
      {
        $self->hour(0);
      }
      
      return 'am';
    }
    elsif($ampm =~ /^p\.?m\.?$/i)
    {
      if($self->hour < 12)
      {
        $self->hour($self->hour + 12);
      }
      
      return 'pm';
    }
    else { croak "AM/PM value not understood: $ampm" }
  }

  return ($self->hour >= 12) ? 'pm' : 'am';
}

sub as_string 
{
  my($self) = shift;
  return $self->format($self->default_format);
}

sub format
{
  my($self, $format) = @_;
  
  $format ||= ref($self)->default_format;

  my $hour  = $self->hour;
  my $ihour = $hour > 12 ? ($hour - 12) : $hour;
  my $ns     = $self->nanosecond;

  my %formats =
  (
    'H' => sprintf('%02d', $hour),
    'I' => sprintf('%02d', $ihour),
    'i' => $ihour,
    'M' => sprintf('%02d', $self->minute),
    'S' => sprintf('%02d', $self->second),
    'N' => sprintf('%09d', $ns || 0),
    'n' => defined $ns ? sprintf('.%09d', $ns) : '',
    'p' => uc $self->ampm,
  );

  $formats{'n'} =~ s/([1-9])0+$/$1/;

  for($format)
  {
    s/%([HIiMSNnp])/$formats{$1}/g;
   
    no warnings 'uninitialized';
    s{ ((?:%%|[^%]+)*) % ([1-9]) N }{ $1 . substr(sprintf("%09d", $ns || 0), 0, $2) }gex;

    if(defined $ns)
    {
      s{ ((?:%%|[^%]+)*) % ([1-9]) n }{ "$1." . substr(sprintf("%09d", $ns || 0), 0, $2) }gex;
    }
    else
    {
      s{ ((?:%%|[^%]+)*) % ([1-9]) n }{$1}gx;
    }

    s/%%/%/g;
  }

  return $format;
}

sub parse
{
  my($self, $time) = @_;
  
  if(my($hour, $min, $sec, $fsec, $ampm) = ($time =~ 
  m{^
      (\d\d?) # hour
      (?::(\d\d)(?::(\d\d))?)?(?:\.(\d{0,9}))? # min? sec? nanosec?
      (?:\s*([aApP]\.?[mM]\.?))? # am/pm
    $
  }x))
  {
    $self->hour($hour);
    $self->minute($min);
    $self->second($sec);
    $self->ampm($ampm);

    if(defined $fsec)
    {
      my $len = length $fsec;
  
      if($len < 9)
      {
        $fsec .= ('0' x (9 - $len));
      }
      elsif($len > 9)
      {
        $fsec = substr($fsec, 0, 9);
      }
    }
    
    $self->nanosecond($fsec);
  }
  else
  {
    croak "Could not parse time '$time'";
  }

  return 1;
}

sub as_integer_seconds
{
  my($self) = shift;
  
  return ($self->hour * SECONDS_IN_AN_HOUR) +
         ($self->minute * SECONDS_IN_A_MINUTE) +
         $self->second;
}

sub delta_as_integer_seconds
{
  my($self, %args) = @_;
  return (($args{'hours'} || 0) * SECONDS_IN_AN_HOUR) +
         (($args{'minutes'} || 0) * SECONDS_IN_A_MINUTE) +
         ($args{'seconds'} || 0);
}

sub parse_delta
{
  my($self) = shift;
  
  if(@_ == 1)
  {
    my $delta = shift;
    
    if(my($hour, $min, $sec, $fsec) = ($delta =~ 
    m{^
        (\d+)            # hours
        (?::(\d+))?      # minutes
        (?::(\d+))?      # seconds
        (?:\.(\d{0,9}))? # nanoseconds
      $
    }x))
    {
      if(defined $fsec)
      {
        my $len = length $fsec;
    
        if($len < 9)
        {
          $fsec .= ('0' x (9 - $len));
        }
        
        $fsec = $fsec + 0;
      }
      
      return
      (
        hours       => $hour,
        minutes     => $min,
        seconds     => $sec,
        nanoseconds => $fsec,
      );
    }
    else { croak "Time delta not understood: $delta" }
  }

  return @_;
}

sub add
{
  my($self) = shift;

  my %args = $self->parse_delta(@_);
  my $secs = $self->as_integer_seconds + $self->delta_as_integer_seconds(%args);

  if(defined $args{'nanoseconds'})
  {
    my $ns_arg = $args{'nanoseconds'};
    my $nsec   = $self->nanosecond || 0;

    if($ns_arg + $nsec < NANOSECONDS_IN_A_SECOND)
    {
      $self->nanosecond($ns_arg + $nsec);
    }
    else
    {
      $secs += int(($ns_arg + $nsec) / NANOSECONDS_IN_A_SECOND);
      $self->nanosecond(($ns_arg + $nsec) % NANOSECONDS_IN_A_SECOND);
    }
  }

  $self->init_with_seconds($secs);

  return;
}

sub init_with_seconds
{
  my($self, $secs) = @_;

  if($secs >= SECONDS_IN_A_CLOCK)
  {
    $secs = $secs % SECONDS_IN_A_CLOCK;
  }

  if($secs >= SECONDS_IN_AN_HOUR)
  {
    $self->hour(int($secs / SECONDS_IN_AN_HOUR));
    $secs -= $self->hour * SECONDS_IN_AN_HOUR;
  }
  else { $self->hour(0) }
  
  if($secs >= SECONDS_IN_A_MINUTE)
  {
    $self->minute(int($secs / SECONDS_IN_A_MINUTE));
    $secs -= $self->minute * SECONDS_IN_A_MINUTE;
  }
  else { $self->minute(0) }

  $self->second($secs);

  return;
}

1;
