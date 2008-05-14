package Rose::HTML::Object::Repeatable;

use strict;

use Carp;
use Clone::PP qw(clone);

require Rose::HTML::Form  unless(@Rose::HTML::Form::ISA);
our @ISA = qw(Rose::HTML::Form);

our $VERSION = '0.554';

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 
  [
    'default_prototype_class',
  ],
);

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'default_count' => { interface => 'get_set_init' },
    'prototype',
  ],
);

sub init_default_count { 0 }

sub is_repeatable { 1 }

sub prototype_class
{
  my($self) = shift;

  if(@_)
  {
    return $self->{'prototype_class'} = shift;
  }

  return $self->{'prototype_class'} || ref($self)->default_prototype_class;  
}

sub prototype_spec
{
  my($self) = shift;
  
  if(@_)
  {
    if(@_ == 1)
    {
      if(ref($_[0]) eq 'ARRAY')
      {
        $self->{'prototype_spec'} = shift;
      }
      elsif(ref($_[0]) eq 'HASH')
      {
        $self->{'prototype_spec'} = shift;
      }
      else
      {
        croak "Invalid prototype spec: @_";
      }
    }
    else
    {
      $self->{'prototype_spec'} = [ @_ ];
    }
  }
  
  return $self->{'prototype_spec'};
}

sub prototype_clone
{
  my($self) = shift;
  
  if(my $obj = $self->prototype)
  {
    return clone($obj);
  }
  else
  {
    my $args = $self->prototype_spec || [];
    $args = [ %$args ]  if(ref $args eq 'HASH');
    return $self->prototype_class(@$args);
  }
}

1;
