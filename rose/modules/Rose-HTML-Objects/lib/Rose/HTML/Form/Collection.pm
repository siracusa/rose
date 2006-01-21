package Rose::HTML::Form::Collection;

use strict;

use Carp();

#use Rose::HTML::Form;
#our @ISA = qw(Rose::HTML::Form);

our $VERSION = '0.35';

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

sub form
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

sub compare_forms { $_[1]->name cmp $_[2]->name }

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
  $self->{'form_list'}  = undef;
  $self->{'form_names'} = undef;
}

1;
