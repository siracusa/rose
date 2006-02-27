package Rose::WebApp::Server::Notes;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Server::Notes::Null',
    mp1  => 'Rose::WebApp::Server::Notes::Apache1',
    mp2  => 'Rose::WebApp::Server::Notes::Apache2',
  );
}

1;
