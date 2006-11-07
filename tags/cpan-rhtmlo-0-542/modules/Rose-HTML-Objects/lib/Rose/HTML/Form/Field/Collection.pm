package Rose::HTML::Form::Field::Collection;

use strict;

use Carp();
use Scalar::Util qw(refaddr);

use Rose::HTML::Form::Field::Hidden;

use Rose::HTML::Form::Field;
our @ISA = qw(Rose::HTML::Form::Field);

use Rose::HTML::Form::Constants qw(FF_SEPARATOR);

# Variables for use in regexes
our $FF_SEPARATOR_RE = quotemeta FF_SEPARATOR;

our $VERSION = '0.54';

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    field_type_classes => { interface => 'get_set_all' },
    _field_type_class  => { interface => 'get_set', hash_key => 'field_type_classes' },
    _delete_field_type_class => { interface => 'delete', hash_key => 'field_type_classes' },
  ],
);

__PACKAGE__->field_type_classes
(
  'text'               => 'Rose::HTML::Form::Field::Text',
  'scalar'             => 'Rose::HTML::Form::Field::Text',
  'char'               => 'Rose::HTML::Form::Field::Text',
  'character'          => 'Rose::HTML::Form::Field::Text',
  'varchar'            => 'Rose::HTML::Form::Field::Text',
  'string'             => 'Rose::HTML::Form::Field::Text',

  'text area'          => 'Rose::HTML::Form::Field::TextArea',
  'textarea'           => 'Rose::HTML::Form::Field::TextArea',
  'blob'               => 'Rose::HTML::Form::Field::TextArea',

  'checkbox'           => 'Rose::HTML::Form::Field::Checkbox',
  'check'              => 'Rose::HTML::Form::Field::Checkbox',

  'radio button'       => 'Rose::HTML::Form::Field::RadioButton',
  'radio'              => 'Rose::HTML::Form::Field::RadioButton',

  'checkboxes'         => 'Rose::HTML::Form::Field::CheckboxGroup',
  'checks'             => 'Rose::HTML::Form::Field::CheckboxGroup',
  'checkbox group'     => 'Rose::HTML::Form::Field::CheckboxGroup',
  'check group'        => 'Rose::HTML::Form::Field::CheckboxGroup',

  'radio buttons'      => 'Rose::HTML::Form::Field::RadioButton',
  'radios'             => 'Rose::HTML::Form::Field::RadioButtonGroup',
  'radio button group' => 'Rose::HTML::Form::Field::RadioButtonGroup',
  'radio group'        => 'Rose::HTML::Form::Field::RadioButtonGroup',

  'pop-up menu'        => 'Rose::HTML::Form::Field::PopUpMenu',
  'popup menu'         => 'Rose::HTML::Form::Field::PopUpMenu',
  'menu'               => 'Rose::HTML::Form::Field::PopUpMenu',

  'select box'         => 'Rose::HTML::Form::Field::SelectBox',
  'selectbox'          => 'Rose::HTML::Form::Field::SelectBox',
  'select'             => 'Rose::HTML::Form::Field::SelectBox',

  'submit'             => 'Rose::HTML::Form::Field::Submit',
  'submit button'      => 'Rose::HTML::Form::Field::Submit',

  'reset'              => 'Rose::HTML::Form::Field::Reset',
  'reset button'       => 'Rose::HTML::Form::Field::Reset',

  'file'               => 'Rose::HTML::Form::Field::File',
  'upload'             => 'Rose::HTML::Form::Field::File',

  'password'           => 'Rose::HTML::Form::Field::Password',

  'hidden'             => 'Rose::HTML::Form::Field::Hidden',

  'email'              => 'Rose::HTML::Form::Field::Email',

  'phone'              => 'Rose::HTML::Form::Field::PhoneNumber::US',
  'phone us'           => 'Rose::HTML::Form::Field::PhoneNumber::US',

  'phone us split'     => 'Rose::HTML::Form::Field::PhoneNumber::US::Split',

  'set'                => 'Rose::HTML::Form::Field::Set',

  'time'               => 'Rose::HTML::Form::Field::Time',
  'time split hms'     => 'Rose::HTML::Form::Field::Time::Split::HourMinuteSecond',

  'time hours'         => 'Rose::HTML::Form::Field::Time::Hours',
  'time minutes'       => 'Rose::HTML::Form::Field::Time::Minutes',
  'time seconds'       => 'Rose::HTML::Form::Field::Time::Seconds',

  'date'               => 'Rose::HTML::Form::Field::Date',
  'datetime'           => 'Rose::HTML::Form::Field::DateTime',

  'datetime range'     => 'Rose::HTML::Form::Field::DateTime::Range',

  'datetime start'     => 'Rose::HTML::Form::Field::DateTime::StartDate',
  'datetime end'       => 'Rose::HTML::Form::Field::DateTime::EndDate',

  'datetime split mdy'    => 'Rose::HTML::Form::Field::DateTime::Split::MonthDayYear',
  'datetime split mdyhms' => 'Rose::HTML::Form::Field::DateTime::Split::MDYHMS',
);

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  boolean => 'coalesce_hidden_fields',

  'scalar --get_set_init'  => 
  [
    'field_rank_counter',
  ],
);

#
# Class methods
#

sub field_type_class 
{
  my($class, $type) = (shift, shift);
  return $class->_field_type_class(lc $type, @_) 
}

sub delete_field_type_class 
{
  my($class, $type) = (shift, shift);
  return $class->_delete_field_type_class(lc $type, @_) 
}

#
# Object methods
#

sub init_field_rank_counter { 1 }

sub increment_field_rank_counter
{
  my($self) = shift;
  my $rank = $self->field_rank_counter;
  $self->field_rank_counter($rank + 1);
  return $rank;
}

sub make_field
{
  my($self, $name, $value) = @_;

  return $value  if(UNIVERSAL::isa($value, 'Rose::HTML::Form::Field'));

  my($type, $args);

  if(ref $value eq 'HASH')
  {
    $type = delete $value->{'type'} or Carp::croak "Missing field type";
    $args = $value;
  }
  elsif(!ref $value)
  {
    $type = $value;
    $args = {};
  }
  else
  {
    Carp::croak "Not a Rose::HTML::Form::Field object or hash ref: $value";
  }

  my $class = ref $self || $self;

  my $field_class = $class->field_type_class($type) 
    or Carp::croak "No field class found for field type '$type'";

  unless($field_class->can('new'))
  {
    eval "require $field_class";
    Carp::croak "Failed to load field class $field_class - $@"  if($@);
  }

  # Compound fields require a name
  if(UNIVERSAL::isa($field_class, 'Rose::HTML::Form::Field::Compound'))
  {
    $args->{'name'} = $name;
  }

  return $field_class->new(%$args);
}

sub invalidate_field_caches
{
  my($self) = shift;

  $self->{'field_cache'} = {};
}

sub field
{
  my($self, $name, $field) = @_;

  if(@_ == 3)
  {
    unless(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
    {
      $field = $self->make_field($name, $field);
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

    return $self->{'fields'}{$name} = $self->{'field_cache'}{$name} = $field;
  }

  if($self->{'fields'}{$name})
  {
    return $self->{'fields'}{$name};
  }

  my $sep_pos;

  # Non-hierarchical name
  if(($sep_pos = index($name, FF_SEPARATOR)) < 0)
  {
    return undef; # $self->local_field($name, @_);
  }

  # Check if it's a local compound field  
  my $prefix = substr($name, 0, $sep_pos);
  my $rest   = substr($name, $sep_pos + 1);
  $field = $self->field($prefix);

  if(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field::Compound'))
  {
    $field = $field->field($rest);
    return ($self->{'field_cache'}{$name} = $field)  if($field);
  }

  return undef;
}

sub find_parent_field
{
  my($self, $name) = @_;

  # Non-hierarchical name
  if(index($name, FF_SEPARATOR) < 0)
  {
    return $self->local_form($name) ? ($self, $name) : undef;
  }

  my $parent_form;

  while($name =~ s/^([^$FF_SEPARATOR_RE]+)$FF_SEPARATOR_RE//o)
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

      if(refaddr($field) eq refaddr($self))
      {
        Carp::croak "Cannot nest a field within itself";
      }

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

      if(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
      {
        if(refaddr($field) eq refaddr($self))
        {
          Carp::croak "Cannot nest a field within itself";
        }
      }
      else
      {
        $field = $self->make_field($arg, $field);
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
    #$field->name; # Pull the new name through to the name HTML attribute
  }
}

sub children 
{
  Carp::croak "children() does not take any arguments"  if(@_ > 1);
  return wantarray ? shift->fields() : (shift->fields() || []);
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
  my($self) = shift;
  $self->_clear_field_generated_values;
  $self->{'fields'} = {};
  $self->field_rank_counter(undef);
  return;
}

sub delete_field
{
  my($self, $name) = @_;

  $name = $name->name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form::Field'));

  $self->_clear_field_generated_values;

  delete $self->{'field_cache'}{$name};
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
  $self->invalidate_field_caches;
}

sub hidden_field
{
  my($self) = shift;

  no warnings 'uninitialized';
  my $name = $self->fq_name;

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
