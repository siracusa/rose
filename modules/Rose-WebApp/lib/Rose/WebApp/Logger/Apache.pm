package Rose::WebApp::Logger::Apache;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Logger::Apache1', 
    mp1  => 'Rose::WebApp::Logger::Apache1', 
    mp2  => 'Rose::WebApp::Logger::Apache2',
  );
}

1;
