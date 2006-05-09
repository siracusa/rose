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

sub notes
{
  return @_ > 1 ? 
    $_[0]->{'notes'} = $_[1] :
    $_[0]->{'notes'} ||= Rose::WebApp::Server::Notes->new;
}

1;
