package Rose::HTML::Form::Collection;

use strict;

use Carp();

#use Rose::HTML::Form;
#our @ISA = qw(Rose::HTML::Form);

our $VERSION = '0.35';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => 
  [
    'form_rank_counter',
  ],
);

sub init_form_rank_counter { 1 }

sub increment_form_rank_counter
{
  my($self) = shift;
  my $rank = $self->form_rank_counter;
  $self->form_rank_counter($rank + 1);
  return $rank;
}

sub _form
{
  my($self, $name, $form) = @_;

  if(@_ == 3)
  {
    unless(UNIVERSAL::isa($form, 'Rose::HTML::Form'))
    {
      Carp::croak "Not a Rose::HTML::Form object: $form";
    }

    $form->form_name($name);
    $form->parent_form($self);

    $self->_clear_form_generated_values;

    unless(defined $form->rank)
    {
      $form->rank($self->increment_form_rank_counter);
    }

    return $self->{'forms'}{$name} = $form;
  }

  if(exists $self->{'forms'}{$name})
  {
    return $self->{'forms'}{$name};
  }

  return undef;
}

sub add_forms
{
  my($self) = shift;

  while(@_)
  {
    my $arg = shift;

    if(UNIVERSAL::isa($arg, 'Rose::HTML::Form'))
    {
      unless(defined $arg->rank)
      {
        $arg->rank($self->increment_form_rank_counter);
      }

      $self->form($arg->form_name => $arg);
    }
    else
    {
      my $form = shift;

      unless(UNIVERSAL::isa($form, 'Rose::HTML::Form'))
      {
        Carp::croak "Not a Rose::HTML::Form object: $form";
      }

      unless(defined $form->rank)
      {
        $form->rank($self->increment_form_rank_counter);
      }

      $self->form($arg => $form);
    }
  }

  $self->_clear_form_generated_values;

  return  unless(defined wantarray);
  return $self->forms;
}

*add_form = \&add_forms;

# XXX: add forms only in add_form, only by simple name
# XXX: add fields only in add_field, only by simple name
# XXX: form() only do lookup, pass add onto add_form after looking up deepest form
# XXX: field() only do lookup, pass add onto add_field after looking up deepest form


sub compare_forms { no warnings; $_[1]->rank cmp $_[2]->rank }

sub forms
{
  my($self) = shift;

  if(my $forms = $self->{'form_list'})
  {
    return wantarray ? @$forms : $forms;
  }

  my $forms = $self->{'forms'};

  $self->{'form_list'} = [ grep { defined } map { $forms->{$_} } $self->form_names ];

  return wantarray ? @{$self->{'form_list'}} : $self->{'form_list'};
}

sub form_names
{
  my($self) = shift;

  if(my $names = $self->{'form_names'})
  {
    return wantarray ? @$names : $names;
  }

  my @info;

  while(my($name, $form) = each %{$self->{'forms'}})
  {
    push(@info, [ $name, $form ]);
  }

  $self->{'form_names'} = 
    [ map { $_->[0] } sort { $self->compare_forms($a->[1], $b->[1]) } @info ];

  return wantarray ? @{$self->{'form_names'}} : $self->{'form_names'};
}

sub delete_forms 
{
  $_[0]->_clear_form_generated_values;
  $_[0]->{'forms'} = {};
  $_[0]->form_rank_counter(undef);
  return;
}

sub delete_form
{
  my($self, $name) = @_;

  $name = $name->name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form'));

  $self->_clear_form_generated_values;

  delete $self->{'forms'}{$name};
}

sub clear_forms
{
  my($self) = shift;

  foreach my $form ($self->forms)
  {
    $form->clear();
  }
}

sub reset_forms
{
  my($self) = shift;

  foreach my $form ($self->forms)
  {
    $form->reset();
  }
}

sub _clear_form_generated_values
{
  my($self) = shift;  
  $self->{'field_list'}  = undef;
  $self->{'field_names'} = undef;
  $self->{'form_list'}   = undef;
  $self->{'form_names'}  = undef;
}

use constant FORM_SEPARATOR => '.';
our $FORM_SEPARATOR = FORM_SEPARATOR;

sub subform_name
{
  my($self, $name) = @_;
  my $form_name = $self->form_name;
  return $name  unless(defined $form_name);
  return $name  if(index($name,  $form_name . FORM_SEPARATOR) == 0);
  return $self->form_name . FORM_SEPARATOR . $name
}

use constant FIELD_SEPARATOR => '.';
our $FIELD_SEPARATOR = FIELD_SEPARATOR;

sub subfield_name
{
  my($self, $name) = @_;
  return $name  if(index($name,  $self->name . FIELD_SEPARATOR) == 0);
  return $self->name . FIELD_SEPARATOR . $name
}

sub form_name
{
  my($self) = shift;

  return $self->{'form_name'}  unless(@_);
  my $old_name = $self->{'form_name'};
  my $name     = $self->{'form_name'} = shift;
  my %forms;

  if(defined $old_name && defined $name && $name ne $old_name)
  {
    my $replace = qr(^$old_name$FORM_SEPARATOR);

    foreach my $form ($self->forms)
    {
      my $subform_name = $form->form_name;
      $subform_name =~ s/$replace/$name$FORM_SEPARATOR/;
      #$Debug && warn $form->form_name, " -> $subform_name\n";
      $form->form_name($subform_name);
      $forms{$subform_name} = $form;
    }

    $self->delete_forms;
    $self->add_forms(%forms);
  }

  return $name;
}

sub form
{
  my($self, $name) = (shift, shift);

  $Debug && warn "name($name) = ", $self->subform_name($name), "\n";
  $name = $self->subform_name($name);

  #return $self->form($name, @_)  if(@_);

  # Dig out sub-subforms
  if(index($name, FORM_SEPARATOR) != rindex($name, FORM_SEPARATOR))
  {
    my $form_name    = $name;
    my $subform_name = $name;

    while(!defined $self->_form($form_name))
    {
      unless($form_name =~ s/$FORM_SEPARATOR[^$FORM_SEPARATOR]+$//o)
      {
        # No such form: create or fail
	    if(@_)
	    {
	      my $form = $self->_form($name, @_);
	      $self->_form_prefix_fields($form, $name);
	      return $form;
	    }
        return undef;
      }
    }

    my $parent_form = $self->_form($form_name);
    
    if(@_)
    {
      my $form = $parent_form->_form($subform_name, @_);
      $self->_form_prefix_fields($form, $subform_name);
    }

    return $parent_form->_form($subform_name);
  }
  else
  {
    if(@_)
    {
      my $form = $self->_form($name, @_);
      $self->_form_prefix_fields($form, $name);
      return $form;
    }
    
    return $self->_form($name);
  }
}

sub _form_prefix_fields
{
  my($self, $form, $prefix) = @_;

  # Name-prefix all the fields in this form
  foreach my $field ($form->fields)
  {
    $form->delete_field($field->field_name);
	$form->field($prefix . FIELD_SEPARATOR . $field->name => $field);
  }
}


sub field
{
  my($self, $name, $field) = @_;

  my $form;
  my $name_prefix = '';

  # Dig out the appropriate sub-subform, if necessary
  if(index($name, FORM_SEPARATOR) >= 0)
  {
    $name =~ s/([^$FORM_SEPARATOR]+)$FORM_SEPARATOR//o;
    my $form_name = $1;

    while(index($name, FORM_SEPARATOR) >= 0 && !defined $self->form($form_name))
    {
      $name =~ s/([^$FORM_SEPARATOR]+)$FORM_SEPARATOR//o;
      $form_name .= FORM_SEPARATOR . $1;
    }

    $name_prefix = $form_name . FIELD_SEPARATOR;
    $form = $self->form($form_name) || $self;
  }
  else { $form = $self }

  if(@_ == 3)
  {
    unless(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field'))
    {
      Carp::croak "Not a Rose::HTML::Form::Field object: $field";
    }

    $field->name($name_prefix . $name);
    $field->field_name($name);
    $field->parent_field($form);

    $self->_clear_field_generated_values;

    unless(defined $field->rank)
    {
      $field->rank($form->increment_field_rank_counter);
    }
    
    $form->{'fields'}{$name} = $field;
  }
  
  if(exists $form->{'fields'}{$name})
  {
    return $form->{'fields'}{$name};
  }
  elsif($name_prefix)
  {
    return $form->field($name);
  }

  return undef;
}


1;
