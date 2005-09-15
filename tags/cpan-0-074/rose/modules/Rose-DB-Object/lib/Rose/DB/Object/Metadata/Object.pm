package Rose::DB::Object::Metadata::Object;

use strict;

use Scalar::Util();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

sub parent
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'parent'} = shift)  if(@_);
  return $self->{'parent'};
}

1;
