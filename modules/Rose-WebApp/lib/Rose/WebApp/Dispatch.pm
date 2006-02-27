package Rose::WebApp::Apache::Dispatch;

use strict;

BEGIN
{
  use Rose::WebApp::Server::Select;
  Rose::WebApp::Server::Select::choose_super
  (
    null => 'Rose::WebApp::Dispatch::Null',
    mp1  => 'Rose::WebApp::Dispatch::Apache1', 
    mp2  => 'Rose::WebApp::Dispatch::Apache2',
  );
}

1;
