package Rose::WebApp::SelfStarter;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::SelfStarter::Null', 
    mp1  => 'Rose::WebApp::SelfStarter::Apache1', 
    mp2  => 'Rose::WebApp::SelfStarter::Apache2',
  );

  __PACKAGE__->register_subclass;
}

our $VERSION = '0.01';

sub feature_name { 'selfstarter' }

1;
