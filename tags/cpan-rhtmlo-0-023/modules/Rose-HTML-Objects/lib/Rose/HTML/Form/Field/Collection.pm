package Rose::HTML::Form::Field::Collection;

use strict;

use Carp();

use Rose::HTML::Form::Field::Hidden;

use Rose::HTML::Form::Field;
our @ISA = qw(Rose::HTML::Form::Field);

our $VERSION = '0.011';

use Rose::Object::MakeMethods::Generic
(
  boolean => 'coalesce_hidden_fields',
);

sub field
{
  my($self, $name, $field) = @_;

  if(@_ == 3)
  {
    unless(ref $field && $field->isa('Rose::HTML::Form::Field'))
    {
      Carp::croak "Not a Rose::HTML::Form::Field object: $field";
    }

    $field->name($name);
    $field->parent_field($self);

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

    if(ref($arg) && $arg->isa('Rose::HTML::Form::Field'))
    {
      $self->field($arg->name => $arg)
    }
    else
    {
      unless(ref $_[0] && $_[0]->isa('Rose::HTML::Form::Field'))
      {
        Carp::croak "Not a Rose::HTML::Form::Field object: $_[0]";
      }

      $self->field($arg => shift);
    }
  }

  return  unless(defined wantarray);
  return $self->fields;
}

*add_field = \&add_fields;

sub fields
{
  my $fields = $_[0]->{'fields'};

  return (wantarray) ? map { $fields->{$_} }  sort keys %$fields :
                       [ map { $fields->{$_} }  sort keys %$fields ];
}

sub field_names
{
  return (wantarray) ? sort keys %{$_[0]->{'fields'}} : 
                       [ sort keys %{$_[0]->{'fields'}} ];
}

sub delete_fields { $_[0]->{'fields'} = {} }

sub delete_field
{
  my($self, $name) = @_;

  $name = $name->name  if(ref $name && $name->isa('Rose::HTML::Form::Field'));

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
