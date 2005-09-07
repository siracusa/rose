#!/usr/bin/perl

# Default Perl startup file

BEGIN
{
  use Apache();
  use Apache::Server();
  use lib Apache->server_root_relative('../perl/lib');
  use lib Apache->server_root_relative('../../../lib');
}

# Don't do expensive Params::Validate validation in production
#if(...)
#{
#  $Params::Validate::NO_VALIDATION = 1;
#}

##
## CPAN mdoules
##

use Apache::Log();
use Apache::Util();
use Apache::Cookie();
use Apache::Constants();

#use Apache::SizeLimit();
#$Apache::SizeLimit::CHECK_EVERY_N_REQUESTS = 5;
#$Apache::SizeLimit::MAX_PROCESS_SIZE = 70 * 1024; # in KB

#use HTML::Mason();
#use HTML::Mason::ApacheHandler();

use Rose::Site::WebSite;
use Rose::WebApp::View::Mason;

use Rose::Test::WebSite;
use Rose::Test::Apache1;
use Rose::Test::Apache1::Notes;
use Rose::Test::Apache1::Module;
use Rose::Test::WebApp;

use Rose::WebApp::Apache1::Dispatch;

1;
