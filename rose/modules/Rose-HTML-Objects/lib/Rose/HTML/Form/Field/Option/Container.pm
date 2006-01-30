package Rose::HTML::Form::Field::Option::Container;

use strict;

use Carp();

use Rose::HTML::Form::Field::Group;
use Rose::HTML::Form::Field::Group::OnOff;
use Rose::HTML::Form::Field::WithContents;
our @ISA = qw(Rose::HTML::Form::Field::Group::OnOff Rose::HTML::Form::Field::WithContents);

require Rose::HTML::Form::Field::Option;
require Rose::HTML::Form::Field::OptionGroup;

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::WithContents->import_methods(
{
  html_tag  => '_html_tag',
  xhtml_tag => '_xhtml_tag',
});

our $VERSION = '0.011';

sub _item_class       { 'Rose::HTML::Form::Field::Option' }
sub _item_group_class { 'Rose::HTML::Form::Field::OptionGroup' }
sub _item_name        { 'option' }
sub _item_name_plural { 'options' }

*options = \&Rose::HTML::Form::Field::Group::items;
*option  = \&Rose::HTML::Form::Field::Group::OnOff::item;
*option_group = \&Rose::HTML::Form::Field::Group::OnOff::item_group;

*add_options = \&Rose::HTML::Form::Field::Group::add_items;
*add_option  = \&Rose::HTML::Form::Field::Group::add_item;

*_args_to_items = \&Rose::HTML::Form::Field::Group::_args_to_items;

sub html_element  { 'select' }
sub xhtml_element { 'select' }

#sub name { shift->html_attr('name', @_) }

sub html_field
{
  my($self) = shift;
  $self->contents("\n" . join("\n", map { $_->html_field } $self->options) . "\n");
  return $self->_html_tag(@_);
}

sub xhtml_field
{
  my($self) = shift; 
  $self->contents("\n" . join("\n", map { $_->xhtml_field } $self->options) . "\n");
  return $self->_xhtml_tag(@_);
}

sub input_value
{
  my($self) = shift;

  if(@_ && (@_ > 1 || (ref $_[0] eq 'ARRAY' && @{$_[0]} > 1)) && !$self->multiple)
  {
    Carp::croak "Attempt to select multiple values in a non-multiple " . ref($self);
  }

  my $values = $self->SUPER::input_value(@_);

  Carp::croak "Non-multiple ", ref($self), " has multiple values: ", join(', ', @$values)
    if(@$values > 1 && !$self->multiple);

  return wantarray ? @$values : $values;
}

sub hidden_fields
{
  my($self) = shift;

  my @hidden;

  foreach my $item ($self->items)
  {
    if($item->internal_value)
    {
      push(@hidden, $item->hidden_field);
      $hidden[-1]->name($self->name);
    }
  }

  return (wantarray) ? @hidden : \@hidden;
}

1;

