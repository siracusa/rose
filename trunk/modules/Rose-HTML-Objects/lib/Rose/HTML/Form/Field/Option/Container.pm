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

our $VERSION = '0.551';

sub _item_class       { 'Rose::HTML::Form::Field::Option' }
sub _item_group_class { 'Rose::HTML::Form::Field::OptionGroup' }
sub _item_name        { 'option' }
sub _item_name_plural { 'options' }

*options               = \&Rose::HTML::Form::Field::Group::items;
*options_localized     = \&Rose::HTML::Form::Field::Group::items_localized;
*option                = \&Rose::HTML::Form::Field::Group::OnOff::item;
*option_group          = \&Rose::HTML::Form::Field::Group::OnOff::item_group;
*visible_options       = \&Rose::HTML::Form::Field::Group::visible_items;

*add_options           = \&Rose::HTML::Form::Field::Group::add_items;
*add_option            = \&add_options;
*add_options_localized = \&Rose::HTML::Form::Field::Group::add_items_localized;
*add_option_localized  = \&add_options_localized;

*add_options_localized = \&Rose::HTML::Form::Field::Group::add_items_localized;
*add_option_localized  = \&Rose::HTML::Form::Field::Group::add_item_localized;

*choices           = \&options;
*choices_localized = \&options_localized;

*_args_to_items = \&Rose::HTML::Form::Field::Group::_args_to_items;

*show_all_options = \&Rose::HTML::Form::Field::Group::show_all_items;
*hide_all_options = \&Rose::HTML::Form::Field::Group::hide_all_items;

*delete_option  = \&Rose::HTML::Form::Field::Group::delete_item;
*delete_options = \&Rose::HTML::Form::Field::Group::delete_items;

*delete_option_group  = \&Rose::HTML::Form::Field::Group::delete_item_group;
*delete_option_groups = \&Rose::HTML::Form::Field::Group::delete_item_groups;

sub html_element  { 'select' }
sub xhtml_element { 'select' }

#sub name { shift->html_attr('name', @_) }

sub html_field
{
  my($self) = shift;
  $self->contents("\n" . join("\n", map { $_->html_field } $self->visible_options) . "\n");
  return $self->_html_tag(@_);
}

sub xhtml_field
{
  my($self) = shift; 
  $self->contents("\n" . join("\n", map { $_->xhtml_field } $self->visible_options) . "\n");
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
    if(defined $item->internal_value)
    {
      # Derek Watson suggests this conditional modifier, but
      # I've yet to see the error is works around...
      $hidden[-1]->name($self->name)
        if(push(@hidden, $item->hidden_field));
    }
  }

  return (wantarray) ? @hidden : \@hidden;
}

sub hidden
{
  my($self) = shift;

  if(@_)
  {
    if($self->{'_hidden'} = shift(@_) ? 1 : 0)
    {
      foreach my $option ($self->options)
      {
        $option->selected(undef);
      }
    }
  }

  return $self->{'_hidden'};
}

sub hide { shift->hidden(1) }
sub show { shift->hidden(0) }

1;

