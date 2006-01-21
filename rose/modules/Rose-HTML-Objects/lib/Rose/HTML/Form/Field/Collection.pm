package Rose::HTML::Form::Field::Collection;

use strict;

use Carp();

use Rose::HTML::Form::Field::Hidden;

use Rose::HTML::Form::Field;
our @ISA = qw(Rose::HTML::Form::Field);

our $VERSION = '0.32';

use Rose::Object::MakeMethods::Generic
(
  boolean => 'coalesce_hidden_fields',

  'scalar --get_set_init'  => 
  [
    'field_rank_counter',
  ],
);

sub init_field_rank_counter { 1 }

sub increment_field_rank_counter
{
  my($self) = shift;
  my $rank = $self->field_rank_counter;
  $self->field_rank_counter($rank + 1);
  return $rank;
}

sub field
{
  my($self, $name, $field) = @_;

  if(@_ == 3)
  {
    unless(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
    {
      Carp::croak "Not a Rose::HTML::Form::Field object: $field";
    }

    $field->name($name);
    $field->field_name($name);
    $field->parent_field($self);

    $self->_clear_field_generated_values;

    unless(defined $field->rank)
    {
      $field->rank($self->increment_field_rank_counter);
    }

    return $self->{'fields'}{$name} = $field;
  }

  if(exists $self->{'fields'}{$name})
  {
    return $self->{'fields'}{$name};
  }

  return undef;
}

sub add_fields
{
  my($self) = shift;

  while(@_)
  {
    my $arg = shift;

    if(UNIVERSAL::isa($arg, 'Rose::HTML::Form::Field'))
    {
      unless(defined $arg->rank)
      {
        $arg->rank($self->increment_field_rank_counter);
      }

      $self->field($arg->name => $arg);
    }
    else
    {
      my $field = shift;

      unless(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
      {
        Carp::croak "Not a Rose::HTML::Form::Field object: $field";
      }

      unless(defined $field->rank)
      {
        $field->rank($self->increment_field_rank_counter);
      }

      $self->field($arg => $field);
    }
  }

  $self->_clear_field_generated_values;

  return  unless(defined wantarray);
  return $self->fields;
}

*add_field = \&add_fields;

sub compare_fields { $_[1]->name cmp $_[2]->name }

sub fields
{
  my($self) = shift;

  if(my $fields = $self->{'field_list'})
  {
    return wantarray ? @$fields : $fields;
  }

  my $fields = $self->{'fields'};

  $self->{'field_list'} = [ grep { defined } map { $fields->{$_} } $self->field_names ];

  return wantarray ? @{$self->{'field_list'}} : $self->{'field_list'};
}

sub field_names
{
  my($self) = shift;

  if(my $names = $self->{'field_names'})
  {
    return wantarray ? @$names : $names;
  }

  my @info;

  while(my($name, $field) = each %{$self->{'fields'}})
  {
    push(@info, [ $name, $field ]);
  }

  $self->{'field_names'} = 
    [ map { $_->[0] } sort { $self->compare_fields($a->[1], $b->[1]) } @info ];

  return wantarray ? @{$self->{'field_names'}} : $self->{'field_names'};
}

sub delete_fields 
{
  $_[0]->_clear_field_generated_values;
  $_[0]->{'fields'} = {};
  $_[0]->field_rank_counter(undef);
  return;
}

sub delete_field
{
  my($self, $name) = @_;

  $name = $name->name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form::Field'));

  $self->_clear_field_generated_values;

  delete $self->{'fields'}{$name};
}

sub clear_fields
{
  my($self) = shift;

  foreach my $field ($self->fields)
  {
    $field->clear();
  }
}

sub reset_fields
{
  my($self) = shift;

  foreach my $field ($self->fields)
  {
    $field->reset();
  }
}

sub _clear_field_generated_values
{
  my($self) = shift;  
  $self->{'field_list'}  = undef;
  $self->{'field_names'} = undef;
}

sub hidden_field
{
  my($self) = shift;

  my $name = $self->html_attr_exists('name') ? $self->html_attr('name') : 
             $self->can('name') ? $self->name : undef;

  return 
    Rose::HTML::Form::Field::Hidden->new(
      name  => $name,
      value => $self->output_value);
}

sub hidden_fields
{
  my($self) = shift;

  my @hidden;

  if($self->coalesce_hidden_fields)
  {
    foreach my $field ($self->fields)
    {
      push(@hidden, $field->hidden_field);
    }
  }
  else
  {
    foreach my $field ($self->fields)
    {
      push(@hidden, $field->hidden_fields);
    }
  }

  return (wantarray) ? @hidden : \@hidden;
}

sub html_hidden_field
{
  my($self) = shift;

  if(defined $self->output_value)
  {
    return $self->hidden_field->html_field;
  }

  return $self->html_hidden_fields;
}

sub xhtml_hidden_field
{
  my($self) = shift;

  if(defined $self->output_value)
  {
    return $self->hidden_field->xhtml_field;
  }

  return $self->xhtml_hidden_fields;
}

sub html_hidden_fields
{
  my($self) = shift;

  my @html;

  foreach my $field ($self->hidden_fields(@_))
  {
    push(@html, $field->html_field);
  }

  return (wantarray) ? @html : join("\n", @html);
}

sub xhtml_hidden_fields
{
  my($self) = shift;

  my @xhtml;

  foreach my $field ($self->hidden_fields(@_))
  {
    push(@xhtml, $field->xhtml_field);
  }

  return (wantarray) ? @xhtml : join("\n", @xhtml);
}

1;
