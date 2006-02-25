package Rose::WebApp::Child;

use strict;

use Scalar::Util();

sub app
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'app'} = shift)  if(@_);
  return $self->{'app'};
}

1;
