package Rose::WebApp::Feature;

use strict;

use Carp();

use Rose::WebApp;
our @ISA = qw(Rose::WebApp);

our $VERSION = '0.01';

sub feature_name
{
  my($self_or_class) = shift;

  my $class = ref $self_or_class || $self_or_class;

  if($class eq __PACKAGE__)
  {
    Carp::confess "feature_name() should only be called from subclasses of ", 
                  __PACKAGE__;
  }
  
  # Transform "My::Special::WithCoolFeature" into "cool-feature"
  for(my $name = $class)
  {
    s/::(?:With(?=[A-Z]))?(\w+)$//;
    s/([a-z]\d*|^\d+)([A-Z])/$1-$2/g;
  }

  return $name;
}

1;
