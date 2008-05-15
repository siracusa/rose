package Rose::HTML::Object::Message::Localized;

use strict;

use Carp;
use Rose::HTML::Object::Message::Localizer;

use Rose::HTML::Object::Message;
our @ISA = qw(Rose::HTML::Object::Message);

our $VERSION = '0.54';

#our $Debug = 0;

use overload
(
  '""'   => sub { shift->localized_text },
  'bool' => sub { 1 },
  '0+'   => sub { 1 },
   fallback => 1,
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'default_localizer',
    'default_locale',
  ],
);

__PACKAGE__->default_localizer(Rose::HTML::Object::Message::Localizer->new);

sub args
{
  my($self) = shift;

  if(@_)
  {
    my %args;

    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      my $i = 1;
      %args = (map { $i++ => $_ } @{$_[0]});
    }
    elsif(@_ == 1 && ref $_[0] eq 'HASH')
    {
      %args = %{$_[0]};

      my $i = 1;

      foreach my $key (sort keys %args)
      {
        $args{$i} = $args{$key}  unless(exists $args{$i});
        $i++;
      }
    }
    else
    {
      my $i = 1;
      %args = map { $i++ => $_ } @_;
    }

    $self->{'args'} = \%args;

    return wantarray ? %{$self->{'args'}} : $self->{'args'};
  }

  return wantarray ? %{$self->{'args'} || {}} : ($self->{'args'} ||= {});
}

sub localized_text
{
  my($self) = shift;

  my $localizer = $self->localizer;

  return $localizer->localize_message(
           message => $self, 
           parent  => $self->parent,
           locale  => $self->locale, 
           args    => scalar $self->args);
}

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

    my $localizer = $invocant->{'localizer'};

    unless($localizer)
    {
      if(my $parent = $invocant->parent)
      {
        if(my $localizer = $parent->localizer)
        {
          return $localizer;
        }
      }
      else { return $class->default_localizer }
    }

    return $localizer || $class->default_localizer;
  }
  else # Called as class method
  {
    if(@_)
    {
      return $invocant->default_localizer(shift);
    }

    return $invocant->default_localizer;
  }
}

sub locale
{
  my($invocant) = shift;

  # Called as object method
  if(my $class = ref $invocant)
  {
    if(@_)
    {
      return $invocant->{'locale'} = shift;
    }

    my $locale = $invocant->{'locale'} || $class->default_locale;

    unless($locale)
    {
      if(my $parent = $invocant->parent)
      {
        if(my $locale = $parent->locale)
        {
          return $locale;
        }
      }
      else { return $class }
    }

    return $locale;
  }
  else # Called as class method
  {
    if(@_)
    {
      return $invocant->default_locale(shift);
    }

    return $invocant->default_locale;
  }
}

1;
