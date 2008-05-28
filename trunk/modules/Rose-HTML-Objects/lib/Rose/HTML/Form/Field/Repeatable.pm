package Rose::HTML::Form::Field::Repeatable;

use strict;

use Rose::HTML::Form::Field;

use base 'Rose::HTML::Object::Repeatable::Form';

our $VERSION = '0.554';

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 
  [
    'default_field_class',
  ],
);

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'prototype_field',
  ],
);


__PACKAGE__->default_field_class('Rose::HTML::Form::Field');

#
# Object methods
#

sub is_repeatable_field { 1 }

sub prototype_field_class
{
  my($self) = shift;

  if(@_)
  {
    return $self->{'prototype_field_class'} = shift;
  }

  return $self->{'prototype_field_class'} || ref($self)->default_field_class;  
}

sub prototype_field_spec
{
  my($self) = shift;
  
  if(@_)
  {
    if(@_ == 1)
    {
      if(ref($_[0]) eq 'ARRAY')
      {
        $self->{'prototype_field_spec'} = shift;
      }
      elsif(ref($_[0]) eq 'HASH')
      {
        $self->{'prototype_field_spec'} = shift;
      }
      else
      {
        croak "Invalid prototype spec: @_";
      }
    }
    else
    {
      $self->{'prototype_field_spec'} = [ @_ ];
    }
  }
  
  return $self->{'prototype_field_spec'};
}

sub prototype_field_clone
{
  my($self) = shift;
  
  if(my $obj = $self->prototype_field)
  {
    return clone($obj);
  }
  else
  {
    my $args = $self->prototype_field_spec || [];
    $args = [ %$args ]  if(ref $args eq 'HASH');
    return $self->prototype_field_class->new(@$args);
  }
}

sub prototype_form
{
  my
}

sub prototype_form_clone
{
  my
}

1;
