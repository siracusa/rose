package Rose::HTML::Form::Field::OnOff;

use strict;

use Scalar::Util();

use Rose::HTML::Form::Field::Input;
our @ISA = qw(Rose::HTML::Form::Field::Input);

use Rose::HTML::Form::Constants qw(FF_SEPARATOR);

our $VERSION = '0.551';

use Rose::Object::MakeMethods::Generic
(
  boolean => 'hidden',
);

__PACKAGE__->add_required_html_attrs(
{
  value => 'on',
});

sub value { shift->html_attr('value', @_) }

sub value_label { $_[0]->is_on ? $_[0]->label : undef }

sub internal_value { $_[0]->is_on ? $_[0]->html_attr('value') : undef }
sub output_value   { $_[0]->is_on ? $_[0]->html_attr('value') : undef }

sub hide { shift->hidden(1) }
sub show { shift->hidden(0) }

sub parent_group
{
  my($self) = shift; 

  if(@_)
  {
    if(ref $_[0])
    {
      Scalar::Util::weaken($self->{'parent_group'} = shift);
      return $self->{'parent_group'};
    }
    else
    {
      return $self->{'parent_group'} = shift;
    }
  }

  return $self->{'parent_group'};
}


sub group_context_name
{
  my($self) = shift;
  my $parent_group = $self->parent_group or return;
  return $parent_group->fq_name or return;
}

sub fq_name
{
  my($self) = shift;

  my $name = $self->group_context_name;
  $name = $self->local_name  unless(defined $name);

  return join(FF_SEPARATOR, grep { defined } $self->form_context_name, 
                                             $self->field_context_name,
                                             $name);
}

my $sep = FF_SEPARATOR;

sub fq_moniker
{
  my($self) = shift;

  my $name = $self->group_context_name;

  if(defined $name)
  {
    my $moniker = $self->local_moniker;
    $name =~ s/(?:^|\Q$sep\E)[^$sep]+$/$moniker/o;
  }
  else { $name = $self->local_moniker }

  return join(FF_SEPARATOR, grep { defined } $self->form_context_name,
                                             $self->field_context_name, 
                                             $name);
}

1;
