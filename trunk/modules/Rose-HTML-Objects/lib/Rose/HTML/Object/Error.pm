package Rose::HTML::Object::Error;

use strict;

use Carp;
use Clone::PP();
use Scalar::Util();

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::HTML::Object::Errors qw(CUSTOM_ERROR);

our $VERSION = '0.531';

#our $Debug = 0;

use overload
(
  '""'   => sub { no warnings 'uninitialized'; shift->message . '' },
  'bool' => sub { 1 },
  '0+'   => sub { 1 },
   fallback => 1,
);

use Rose::HTML::Object::MakeMethods
(
  localized_message =>
  [
    'message',
  ],
);

sub as_string { "$_[0]" }

sub parent
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'parent'} = shift)  if(@_);
  return $self->{'parent'};
}

sub localizer 
{
  my($self) = shift;
  
  my $parent = $self->parent;
  
  if(ref $parent || defined $parent)
  {
    return $parent->localizer;
  }
  else
  {
    return Rose::HTML::Object->localizer;
  }
}

sub locale { shift->parent->locale }

sub clone
{
  my($self) = shift;
  my $clone = Clone::PP::clone($self);
  $clone->parent(undef);
  return $clone;
}

sub id
{
  my($self) = shift;

  if(@_)
  {
    return $self->{'id'} = shift;
  }

  my $id = $self->{'id'};
  
  return $id  if(defined $id);

  my $msg = $self->message;
  return CUSTOM_ERROR  if($msg && $msg->is_custom);
  return undef;
}

sub get_localized_message { shift->parent->get_localized_message(@_) }

sub is_custom
{
  my($self) = shift;

  my $id = $self->id;
  
  unless(defined $id)
  {
    my $msg = $self->message;
    
    return 1  if($msg && $msg->is_custom);
    return undef;
  }
  
  return $id == CUSTOM_ERROR;
}

1;
