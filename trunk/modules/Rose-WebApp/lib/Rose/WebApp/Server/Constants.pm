package Rose::WebApp::Server::Constants;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Server::Constants::Null',
    mp1  => 'Rose::WebApp::Server::Constants::Apache1', 
    mp2  => 'Rose::WebApp::Server::Constants::Apache2',
  );
}

1;
