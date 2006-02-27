package Rose::WebApp::Comp;

use strict;

use Scalar::Util();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    'name',
    'path',
  ]
);

sub app
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'app'} = shift)  if(@_);
  return $self->{'app'};
}

# sub path
# {
#   my($self) = shift;
#   $self->{'path'} = shift  if(@_);
#   return (ref $self->{'path'} eq 'CODE') ? 
#     $self->{'path'}->($self, $self->app) : $self->{'path'};
# }

1;
