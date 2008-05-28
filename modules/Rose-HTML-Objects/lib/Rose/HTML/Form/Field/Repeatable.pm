package Rose::HTML::Form::Field::Repeatable;

use strict;

use Clone::PP();

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

__PACKAGE__->default_field_class('Rose::HTML::Form::Field');

#
# Object methods
#

sub is_repeatable_field { 1 }

sub prototype_field
{
  my($self) = shift;

  if(@_)
  {
    $self->_clear_field_generated_values;
    return $self->{'prototype_field'} = shift;
  }

  return $self->{'prototype_field'};
}

sub prototype_field_name
{
  my($self) = shift;

  if(@_)
  {
    $self->_clear_field_generated_values;
    $self->{'prototype_field_name'} = shift;
  }

  return defined $self->{'prototype_field_name'} ? $self->{'prototype_field_name'} : $self->form_name;
}

sub prototype_field_class
{
  my($self) = shift;

  if(@_)
  {
    $self->_clear_field_generated_values;
    return $self->{'prototype_field_class'} = shift;
  }

  return $self->{'prototype_field_class'} || ref($self)->default_field_class;  
}

sub prototype_field_spec
{
  my($self) = shift;

  if(@_)
  {
    $self->_clear_field_generated_values;

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
    return Clone::PP::clone($obj);
  }
  else
  {
    my $args = $self->prototype_field_spec || [];
    $args = [ %$args ]  if(ref $args eq 'HASH');
    return $self->prototype_field_class->new(@$args);
  }
}

sub _clear_field_generated_values
{
  my($self) = shift;
  $self->{'prototype_form'} = undef;
}

sub prototype_form
{
  my($self) = shift;

  unless($self->{'prototype_form'})
  {
    my $form = $self->SUPER::prototye_form;
    my $field = $self->prototype_field_clone;
    $field->local_name($self->prototype_field_name)  unless($field->name);
    $form->add_field($field);
    $self->{'prototype_form'} = $form;
  }

  return $self->{'prototype_form'};
}

sub prototype_form_clone
{
  my($self) = shift;
  return Clone::PP:clone($self->prototype_form);
}

1;
