package Rose::WebApp::Server;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Server::Null',
    mp1  => 'Rose::WebApp::Server::Apache1', 
    mp2  => 'Rose::WebApp::Server::Apache2',
  );
}

1;
