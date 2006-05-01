package Rose::WebApp::SelfStarter::Apache1;

use strict;

use Apache();
use Apache::File();
use Apache::Request();
use Apache::Constants 
  qw(M_POST M_INVALID M_OPTIONS NOT_IMPLEMENTED DECLINED OK);

use Rose::WebApp::Feature;
our @ISA = qw(Rose::WebApp::Feature);

our %Apps;

our $VERSION = '0.01';

our $Debug = 0;

sub handler($$)
{
  my($self, $r) = @_;

  #
  # Get application object
  #

  my $class = ref($self) || $self;
  my $app;

  if($r->dir_config('RoseWebAppNoCache'))
  {
    $app = $class->new;
  }
  else
  {
    $app = $Apps{$class} ||= $class->new;
  }

  $r->register_cleanup(sub { $app->refresh() });

  #
  # Sanity check
  #

  my $method_number = $r->method_number();

  # If this is not a POST request
  if($method_number != M_POST)
  {
    # Chuck the HTTP/1.1 request body, if any
    if((my $ret = $r->discard_request_body) != OK)
    {
      return $ret;
    }
  }

  # Make sure apache handles this type of request
  if($method_number == M_INVALID)
  {
    $r->log_error('Invalid method in request ', $r->the_request);
    return NOT_IMPLEMENTED;
  }

  # Checking for server options?  That's not us.
  if($method_number == M_OPTIONS)
  {
    return DECLINED;
  }

  #
  # Import parameters
  #

  my $apr = Apache::Request->new($r);

  # Parse the form data, if any
  my $status = $apr->parse();

  # Puke if the submission has errors
  unless($status == OK)
  {
    $apr->custom_response($status, $apr->notes("error-notes"));
    return $status;
  }

  my %params;

  foreach my $param ($apr->param())
  {
    my(@vals) = $apr->param($param);

    if(@vals > 1)
    {
      $Debug && print STDERR "$param = array(", join(', ', @vals), ")\n";
      $params{$param} = \@vals;
    }
    else
    {
      $Debug && print STDERR "$param = scalar($vals[0])\n";
      $params{$param} = $vals[0];
    }
  }

  #
  # Prepare for run
  #

  $app->params(\%params);
  $app->apache->request($r);

  $r->content_type('text/html');

  # Support Apache::Filter hooks
  #if(lc $r->dir_config('Filter') eq 'on')
  #{
  #  $r->filter_register;
  #  $app->http_header_sent(1);  
  #}

  #
  # Run app
  #

  $app->run();

  return $app->status;
}

1;
