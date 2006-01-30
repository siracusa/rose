package Rose::HTML::Form::Field::Collection;

use strict;

use Carp();

use Rose::HTML::Form::Field::Hidden;

use Rose::HTML::Form::Field;
our @ISA = qw(Rose::HTML::Form::Field);

use Rose::HTML::Form::Constants qw(FIELD_SEPARATOR FORM_SEPARATOR);

# Variables for use in regexes
our $FIELD_SEPARATOR_RE = quotemeta FIELD_SEPARATOR;
our $FORM_SEPARATOR_RE  = quotemeta FORM_SEPARATOR;

our $VERSION = '0.35';

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

    $field->local_moniker($name);
    
    if($self->isa('Rose::HTML::Form'))
    {
      $field->parent_form($self);
    }
    else
    {
      $field->parent_field($self);
    }

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

  my $sep_pos;

  # Non-hierarchical name
  if(($sep_pos = index($name, FORM_SEPARATOR)) < 0)
  {
    return undef; # $self->local_field($name, @_);
  }

  # First check if it's a local compound field  
  my $prefix = substr($name, 0, $sep_pos);
  my $rest   = substr($name, $sep_pos + 1);
  $field = $self->field($prefix);
  
  if(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field::Compound'))
  {
    $field = $field->field($rest);
    return $field  if($field);
  }

#   my($parent_form, $local_name) = $self->find_parent_form($name);
# 
#   return $parent_form->field($local_name, @_);
  
  return undef;
}

sub find_parent_field
{
  my($self, $name) = @_;

  # Non-hierarchical name
  if(index($name, FORM_SEPARATOR) < 0)
  {
    return $self->local_form($name) ? ($self, $name) : undef;
  }

  my $parent_form;

  while($name =~ s/^([^$FORM_SEPARATOR_RE]+)$FORM_SEPARATOR_RE//o)
  {
    my $parent_name = $1;
    last  if($parent_form = $self->local_form($parent_name));
  }

  return unless(defined $parent_form);
  return wantarray ? ($parent_form, $name) : $parent_form;
}

sub add_fields
{
  my($self) = shift;

  my @added_fields;

  while(@_)
  {
    my $arg = shift;

    if(UNIVERSAL::isa($arg, 'Rose::HTML::Form::Field'))
    {
      my $field = $arg;

      $field->local_name($field->name);
      
      unless(defined $field->rank)
      {
        $field->rank($self->increment_field_rank_counter);
      }

      $self->field($field->local_name => $field);
      push(@added_fields, $field);
    }
    else
    {
      my $field = shift;

      unless(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
      {
        Carp::croak "Not a Rose::HTML::Form::Field object: $field";
      }

      $field->local_moniker($arg);

      unless(defined $field->rank)
      {
        $field->rank($self->increment_field_rank_counter);
      }

      $self->field($arg => $field);
      push(@added_fields, $field);
    }
  }

  $self->_clear_field_generated_values;
  $self->resync_field_names;

  return  unless(defined wantarray);
  return wantarray ? @added_fields : $added_fields[0];
}

*add_field = \&add_fields;

sub compare_fields { $_[1]->name cmp $_[2]->name }

sub resync_field_names
{
  my($self) = shift;
  
  foreach my $field ($self->fields)
  {
    $field->resync_name;
    $field->resync_field_names  if($field->isa('Rose::HTML::Form::Field::Compound'));
#    $field->name; # Pull the new name through to the name HTML attribute
  }
}

sub fields
{
  my($self) = shift;

  if(my $fields = $self->{'field_list'})
  {
    return wantarray ? @$fields : $fields;
  }

  my $fields = $self->{'fields'};

  $self->{'field_list'} = [ grep { defined } map { $fields->{$_} } $self->field_monikers ];

  return wantarray ? @{$self->{'field_list'}} : $self->{'field_list'};
}

sub field_monikers
{
  my($self) = shift;

  if(my $names = $self->{'field_monikers'})
  {
    return wantarray ? @$names : $names;
  }

  my @info;

  while(my($name, $field) = each %{$self->{'fields'}})
  {
    push(@info, [ $name, $field ]);
  }

  $self->{'field_monikers'} = 
    [ map { $_->[0] } sort { $self->compare_fields($a->[1], $b->[1]) } @info ];

  return wantarray ? @{$self->{'field_monikers'}} : $self->{'field_monikers'};
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
  $self->{'field_monikers'} = undef;
}

sub hidden_field
{
  my($self) = shift;

  no warnings 'uninitialized';
  my $name = $self->fq_name;
#   my $name = $self->html_attr_exists('name') ? $self->html_attr('name') : 
#              $self->can('name') ? $self->name : undef;

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
