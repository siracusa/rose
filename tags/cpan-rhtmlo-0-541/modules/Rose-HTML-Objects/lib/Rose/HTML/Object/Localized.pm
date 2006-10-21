package Rose::HTML::Object::Localized;

use strict;

use Carp;
use Rose::HTML::Object::Message::Localizer;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.54';

#our $Debug = 0;

use Rose::HTML::Object::MakeMethods
(
  localized_errors =>
  [
    'errors',
  ],
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'default_localizer',
    'default_locale',
  ],
);

sub localizer
{
  my($invocant) = shift;

  # Called as object method
  if(my $class = ref $invocant)
  {
    if(@_)
    {
      return $invocant->{'localizer'} = shift;
    }

    return $invocant->{'localizer'} || $class->default_localizer;
  }
  else # Called as class method
  {
    if(@_)
    {
      return $invocant->default_localizer(shift);
    }

    return $invocant->default_localizer
  }
}

sub locale
{
  my($invocant) = shift;

  # Called as an object method
  if(my $class = ref $invocant)
  {
    if(@_)
    {
      return $invocant->{'locale'} = shift;
    }

    return $invocant->{'locale'} || $invocant->localizer->locale || 
           $invocant->localizer->default_locale;
  }
  else # Called as a class method
  {
    if(@_)
    {
      return $invocant->default_locale(shift);
    }

    return $invocant->localizer->locale || $invocant->localizer->default_locale;
  }
}

1;
