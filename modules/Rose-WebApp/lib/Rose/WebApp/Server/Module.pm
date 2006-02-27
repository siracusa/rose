package Rose::WebApp::Server::Module;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Server::Module::Null',
    mp1  => 'Rose::WebApp::Server::Module::Apache1',
    mp2  => 'Rose::WebApp::Server::Module::Apache2',
  );
}

1;
