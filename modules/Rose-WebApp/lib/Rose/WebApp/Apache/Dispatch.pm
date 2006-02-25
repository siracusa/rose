package Rose::WebApp::Apache::Dispatch;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::WebApp::Apache0::Dispatch',
    mp1 => 'Rose::WebApp::Apache1::Dispatch', 
    mp2 => 'Rose::WebApp::Apache2::Dispatch'
  );
}

1;
