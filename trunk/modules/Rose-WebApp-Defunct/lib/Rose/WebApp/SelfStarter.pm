package Rose::WebApp::SelfStarter;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::WebApp::Apache0::SelfStarter', 
    mp1 => 'Rose::WebApp::Apache1::SelfStarter', 
    mp2 => 'Rose::WebApp::Apache2::SelfStarter'
  );

  __PACKAGE__->register_subclass;
}

our $VERSION = '0.01';

sub feature_name { 'selfstarter' }

1;
