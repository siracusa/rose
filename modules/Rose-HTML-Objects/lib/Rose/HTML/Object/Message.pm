package Rose::HTML::Object::Message;

use strict;

use Carp;
use Clone::PP;
use Scalar::Util();

use Rose::HTML::Object::Messages qw(CUSTOM_MESSAGE);

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.531';

#our $Debug = 0;

use overload
(
  '""'   => sub { shift->text },
  'bool' => sub { 1 },
  '0+'   => sub { 1 },
   fallback => 1,
);

use Rose::Object::MakeMethods::Generic
(
  scalar => 'id',
);

sub as_string { no warnings 'uninitialized'; "$_[0]" }

sub init
{
  my($self) = shift;
  @_ = (text => @_)  if(@_ == 1);
  $self->SUPER::init(@_);
}

sub parent
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'parent'} = shift)  if(@_);
  return $self->{'parent'};
}

sub clone
{
  my($self) = shift;
  my $clone = Clone::PP::clone($self);
  $clone->parent(undef);
  return $clone;
}

sub text
{
  my($self) = shift;

  if(@_)
  {
    if(UNIVERSAL::isa($_[0], __PACKAGE__))
    {
      $self->id($_[0]->id);
      return $self->{'text'} = $_[0]->text;
    }
    
    $self->id(CUSTOM_MESSAGE);
    return $self->{'text'} = $_[0];
  }

  return $self->{'text'};
}

sub is_custom { no warnings; shift->id == CUSTOM_MESSAGE }

1;
