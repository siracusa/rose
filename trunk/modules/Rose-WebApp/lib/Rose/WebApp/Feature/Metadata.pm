package Rose::WebApp::Feature::Metadata;

use strict;

use Carp();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'class',
  ],
);

sub isa_position
{
  my($self) = shift;

  return $self->{'isa_position'} ||= 'start' unless(@_);

  unless($_[0] =~ /^(?:start|end)$/)
  {
    Carp::croak "Invalid isa position argument: $_[0]";
  }

  return $self->{'isa_position'} = $_[0];
}

1;
