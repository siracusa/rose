package Rose::HTML::Form::Repeatable;

use strict;

use Rose::HTML::Form;

use base 'Rose::HTML::Object::Repeatable';

our $VERSION = '0.554';

__PACKAGE__->default_form_class('Rose::HTML::Form');

#
# Class methods
#

sub default_form_class { shift->default_prototype_class(@_) }

#
# Object methods
#

sub prototype_form       { shift->prototype(@_) }
sub prototype_form_spec  { shift->prototype_spec(@_) }
sub prototype_form_clone { shift->prototype_clone(@_) }

sub is_repeatable_form { 1 }

sub prepare
{
  my($self) = shift;
  my(%args) = @_;

  my $fq_form_name = quotemeta $self->fq_form_name;
  
  my $re = qr(^$fq_form_name\.(\d+)\.);

  my %have_num;

  foreach my $param (keys %{$self->params})
  {
    if($param =~ $re)
    {
      my $num = $1;
      $have_num{$num}++;
      my $form = $self->form($num) || $self->make_form($num);
    }
  }

  unless(%have_num)
  {
    if($self->default_count)
    {
      foreach my $num (1 .. $self->default_count)
      {
        $self->form($num) || $self->make_form($num);
        $have_num{$num}++;
      }
    }
    else
    {
      $self->delete_forms;
    }
  }

  if(%have_num)
  {
    foreach my $form ($self->forms)
    {
      unless($have_num{$form->form_name})
      {
        $self->delete_form($form->form_name);
      }
    }
  }

  $self->SUPER::prepare(@_)  unless(delete $args{'init_only'});
}

sub init_fields
{
  my($self) = shift;
  $self->prepare(init_only => 1);
  $self->SUPER::init_fields(@_);
}

sub make_form
{
  my($self, $num) = @_;

  my $form = $self->prototype_form_clone;

  $form->rank($num);

  $self->add_form($num => $form);
  
  return $form;
}

1;
