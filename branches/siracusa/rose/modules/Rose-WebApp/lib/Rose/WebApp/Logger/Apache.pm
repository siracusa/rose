package Rose::WebApp::Logger::Apache;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp1 => 'Rose::WebApp::Logger::Apache1', 
    mp2 => 'Rose::WebApp::Logger::Apache2'
  );
}

1;
