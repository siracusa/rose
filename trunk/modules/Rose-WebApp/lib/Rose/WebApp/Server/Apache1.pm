package Rose::WebApp::Server::Apache1;

use strict;

use Carp();

use Apache;
use Apache::Log;
use Apache::Util();
use Apache::Cookie();
use Apache::Constants qw(REDIRECT);

use Rose::WebApp::Server::Notes;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

our $Debug = 1;

our $Request_Number = 1;

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'error',
  ],
);

sub new
{
  my $self = shift->SUPER::new(@_);

  $Debug && warn join(' line ', (caller)[0,2]), " - Getting new $self\n";

  $self->apache_request->register_cleanup(sub 
  {
    $Debug && warn "Cleaning up $self\n";
    $self->{'notes'}->clear  if($self->{'notes'});
    $self = undef;
  });

  return $self;
}

sub apache_request
{
  return @_ > 1 ? 
    $_[0]->{'apache_request'} = $_[1] :
    $_[0]->{'apache_request'} ||= Apache->request;
}

sub notes
{
  return @_ > 1 ? 
    $_[0]->{'notes'} = $_[1] :
    $_[0]->{'notes'} ||= Rose::WebApp::Server::Notes->new;
}

sub constant
{
  no strict 'refs';
  &{"Apache::Constants::$_[1]"}();
}

our %LOG_LEVEL_NAME_TO_CONST =
(
  emergency => Apache::Log::EMERG,
  alert     => Apache::Log::ALERT,
  critical  => Apache::Log::CRIT,
  error     => Apache::Log::ERR,
  warn      => Apache::Log::WARNING,
  notice    => Apache::Log::NOTICE,
  info      => Apache::Log::INFO,
  debug     => Apache::Log::DEBUG,
);

# Reverse mapping
our %LOG_LEVEL_CONST_TO_NAME =
(
  Apache::Log::EMERG()   => 'emergency',
  Apache::Log::ALERT()   => 'alert',
  Apache::Log::CRIT()    => 'critical',
  Apache::Log::ERR()     => 'error',
  Apache::Log::WARNING() => 'warn',
  Apache::Log::NOTICE()  => 'notice',
  Apache::Log::INFO()    => 'info',
  Apache::Log::DEBUG()   => 'debug',
);

sub log_level 
{
  my($self) = shift;

  if(@_)
  {
    my $level = shift;
    Carp::croak "Invalid log level: '$level'"  unless(exists $LOG_LEVEL_NAME_TO_CONST{$level});
    $self->apache_request->server->loglevel($LOG_LEVEL_NAME_TO_CONST{$level});
    return $level;
  }

  return $LOG_LEVEL_CONST_TO_NAME{$self->apache_request->server->loglevel} || $self->apache_request->server->loglevel;
}

sub log_level_constant { shift->apache_request->server->loglevel(@_) }

sub log { shift->apache_request->log }

sub log_emergency { shift->apache_request->log->emerg(@_)  }
sub log_alert     { shift->apache_request->log->alert(@_)  }
sub log_critical  { shift->apache_request->log->crit(@_)   }
sub log_error     { shift->apache_request->log_error(@_)   }
sub log_warning   { shift->apache_request->log->warn(@_)   }
sub log_notice    { shift->apache_request->log->notice(@_) }
sub log_info      { shift->apache_request->log->info(@_)   }
sub log_debug     { shift->apache_request->log->debug(@_)  }

sub print { shift->apache_request->print(@_) }

sub escape_html { shift; Apache::Util::escape_html(join('', @_) || '') }

sub location             { $_[0]->apache_request->location }
sub server_root_relative { shift; Apache->server_root_relative(@_) }

sub remote_user { $_[0]->apache_request->connection->user }

sub user_agent
{
  $_[0]->apache_request->header_in('User-Agent') || $ENV{'HTTP_USER_AGENT'} || '';
}

sub hostname { shift->apache_request->hostname }
sub port     { shift->apache_request->server->port }

sub client_ip
{
  my $r = $_[0]->apache_request;

  my $ip = $r->header_in('X-Forwarded-For') || $r->connection()->remote_ip() || '???';

  # Sometimes it's a comma-separated list like "17.254.3.183, 17.254.31.13"
  # Just take the first address.
  $ip =~ s/^.*?\s*(\d+\.\d+\.\d+\.\d+).*/$1/;

  return $ip;
}

sub document_root { shift->apache_request->document_root }

sub path_info
{
  my($self) = shift;

  if(@_)
  {
    return $self->apache_request->path_info($self->notes->path_info($ENV{'PATH_INFO'} = shift));
  }

  return $self->apache_request->path_info;
}

sub requested_uri
{
  my($self) = shift;

  return $self->notes->requested_uri(@_)  if(@_);

  if(my $uri = $self->notes->requested_uri)
  {
    return $uri;
  }

  #$uri ||= $ENV{$AUTH_CONF{'REQ_URI_COOKIE'}};

  my $r = $self->apache_request;

  return $self->notes->requested_uri($r->uri || '/');
}

sub requested_uri_query
{
  my($self) = shift;

  return $self->notes->requested_uri_query(@_)  if(@_);

  if(my $query = $self->notes->requested_uri_query)
  {
    return $query;
  }

  return $self->notes->requested_uri_query(scalar $self->apache_request->args);
}

sub requested_uri_with_query
{
  my($self) = shift;

  my $uri   = $self->requested_uri;
  my $query = $self->requested_uri_query;

  $uri .= "?$query"  if(length $query);

  return $uri;
}

sub referrer
{
  shift->apache_request->header_in('Referer') || $ENV{'HTTP_REFERER'};
}

sub is_secure
{
  my($self) = shift;

  no warnings;

  my $r = $self->apache_request;
  return ($r->header_in('X-Forwarded-For-SSL') ||
          $r->header_in('X-Forwarded-For-Method') eq 'https') ? 1 : 0;
}

sub update_request_id
{
  my($self) = shift;
  my $r = $self->apache_request;
  $Request_Number++  if($r->is_initial_req);
  return $Request_Number;
}

sub request_id { $$ . ':' . $Request_Number }

sub response_content_type { shift->apache_request->content_type(@_) }
sub response_add_header   { shift->apache_request->headers_out->add(@_) }
sub response_status       { shift->apache_request->status(@_) }

sub redirect
{
  my($self, $uri) = @_;

  my $r = $self->apache_request;

  # Stop Apache from re-reading POSTed data (Mason bug)
  #$r->method('GET');
  #$r->headers_in->unset('Content-length');

  # Workaround for this Mason bug:
  # http://www.masonhq.com/resources/todo/view.html?id=292
  $r->content_type('text/html');

  #$r->headers_out->add(Referer  => $r->header_in('Referer'));
  $r->headers_out->add(Location => $uri);
  $r->status(REDIRECT);

  $r->send_http_header;
  Apache::exit();
}

sub internal_redirect
{
  my($self, $uri) = @_;

  my $r = $self->apache_request;

  # Stop Apache from re-reading POSTed data (Mason bug)
  #$r->method('GET');
  #$r->headers_in->unset('Content-length');

  # Workaround for this Mason bug:
  # http://www.masonhq.com/resources/todo/view.html?id=292
  $r->content_type('text/html');

  # Try to let the subprocess know where we're redirecting from
  $ENV{'ROSE_APACHE_REDIRECT_FROM'} = $self->requested_uri_with_query;
  $r->subprocess_env(ROSE_APACHE_REDIRECT_FROM => $ENV{'ROSE_APACHE_REDIRECT_FROM'});

  $Debug && warn "Internal redirect: $uri";

  $r->internal_redirect($uri);
  #$r->send_http_header;
  Apache::exit();
}

sub redirect_from_uri
{
  my($self) = shift;

  my %args;

  if(@_ % 2 == 0)
  {
    %args = @_;
    @_ = ();
  }

  my $uri = $self->notes->redirect_from(@_);
  my $r   = $self->apache_request;

  if(@_)
  {
    $r->subprocess_env('ROSE_APACHE_REDIRECT_FROM' => $_[0]);
  }
  else
  {
    $uri ||= $r->subprocess_env('ROSE_APACHE_REDIRECT_FROM');
  }

  unless(length($uri))
  {
    my $cookies = Apache::Cookie->fetch();

    if(my $cookie = $cookies->{'ROSE_APACHE_REQESTED_URI'})
    {
      $uri = $cookie->value;
    }
    elsif(!$args{'ignore_referrer'})
    {
      $uri = $r->header_in('Referer');
    }
  }

  return $uri;
}

sub redirect_to_uri 
{
  my($self) = shift;

  my $uri = $self->notes->redirect_to_uri(@_);

  unless($uri)
  {
    my $cookies = Apache::Cookie->fetch();

    if(my $cookie = $cookies->{'ROSE_APACHE_REDIRECT_TO'})
    {
      $uri = $cookie->value;
    }
  }

  return $uri;
}

sub send_http_header
{
  shift->apache_request->send_http_header(@_);
}

1;
