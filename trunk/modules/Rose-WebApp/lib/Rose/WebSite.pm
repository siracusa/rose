package Rose::WebSite;

use strict;

use Rose::URI;
use Rose::WebApp::Server;

use Class::Delegator
(
  send =>
  [
    qw(notes user_agent client_ip path_info requested_uri 
       requested_uri_query requested_uri_with_query referrer
       is_secure request_id update_request_id redirect_from_uri
       redirect_to_uri internal_redirect)
  ],
  to => 'server',
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    (map { '_' . $_ }
     qw(site_host_secure site_host_insecure
        site_port_secure site_port_insecure)),

    'default_site_port_secure',
    'default_site_port_insecure',
  ]
);

__PACKAGE__->default_site_port_secure(443);
__PACKAGE__->default_site_port_insecure(80);

sub site_host_secure
{
  my($class) = shift;
  
  return $class->_site_host_secure(@_)  if(@_);

  my $host = $class->_site_host_secure;

  unless($host)
  {
    $host = $class->_site_host_secure($class->server->hostname);
  }

  return $host;
}

sub site_host_insecure
{
  my($class) = shift;
  
  return $class->_site_host_insecure(@_)  if(@_);

  my $host = $class->_site_host_insecure;

  unless($host)
  {
    $host = $class->_site_host_insecure($class->server->hostname);
  }

  return $host;
}

sub site_port_secure
{
  my($class) = shift;

  return $class->_site_port_secure(@_)  if(@_);

  my $port = $class->_site_port_secure;

  return $port  if($port);
  return $class->default_site_port_secure  unless($class->is_secure);

  unless($port)
  {
    $port = $class->_site_port_secure($class->server->port);
  }

  return $port;
}

sub site_port_insecure
{
  my($class) = shift;

  return $class->_site_port_insecure(@_)  if(@_);

  my $port = $class->_site_port_insecure;

  return $port  if($port);
  return $class->default_site_port_insecure  if($class->is_secure);

  unless($port)
  {
    $port = $class->_site_port_insecure($class->server->port);
  }

  return $port;
}

#sub site_port_secure   { 443 }
#sub site_port_insecure { 80 }

our $Server;

sub server
{ 
  return $Server = $_[1]  if(@_ > 1);
  return $Server ||= Rose::WebApp::Server->new;
}

sub site_domain_insecure
{
  my $domain = shift->site_host_insecure;
  $domain =~ s/.*\.([^.]+\.[^.]+\.?)$/.$1/;
  return $domain;
}

sub site_domain_secure
{
  my $domain = shift->site_host_secure;
  $domain =~ s/.*\.([^.]+\.[^.]+\.?)$/.$1/;
  return $domain;
}

sub site_domain
{
  ($_[0]->is_secure) ? $_[0]->site_domain_secure :  
                       $_[0]->site_domain_insecure;
}

sub site_host
{
  ($_[0]->is_secure) ? $_[0]->site_host_secure :  
                       $_[0]->site_host_insecure;
}

sub site_port
{
  ($_[0]->is_secure) ? $_[0]->site_port_secure :  
                       $_[0]->site_port_insecure;
}

sub site_url_secure
{
  my($class, $path) = @_;

  my $uri = Rose::URI->new($path || '');
  my $site_uri = Rose::URI->new('https://' . $class->site_host_secure);

  $site_uri->port($class->site_port_secure)
    if($class->site_port_secure != 443);

  $site_uri->path($uri->path);
  $site_uri->query($uri->query);
  $site_uri->fragment($uri->fragment);

  return $site_uri;
}

sub site_url_insecure
{
  my($class, $path) = @_;

  my $uri = Rose::URI->new($path || '');
  my $site_uri = Rose::URI->new('http://' . $class->site_host_insecure);

  $site_uri->port($class->site_port_insecure)
    if($class->site_port_insecure != 80);

  $site_uri->path($uri->path);
  $site_uri->query($uri->query);
  $site_uri->fragment($uri->fragment);

  return $site_uri;
}

sub site_url
{
  my($class, $path) = @_;

  return ($class->is_secure) ? $class->site_url_secure($path) :
                               $class->site_url_insecure($path);
}

sub current_url_secure
{
  my($class) = shift;
  return $class->site_url_secure($class->requested_uri_with_query);
}

sub current_url_insecure
{
  my($class) = shift;
  return $class->site_url_insecure($class->requested_uri_with_query);
}

sub require_secure
{
  my($class) = shift;

  return 1  if($class->is_secure);

  $class->redirect($class->current_url_secure);
}

sub redirect
{
  my($class, $uri) = @_;

  unless($uri =~ m{^\w+://})
  {
    $uri = $class->site_url($uri);
  }

  # Escape clearly unescaped URIs
  if($uri =~ /\s/)
  {
    $uri = Rose::HTML::Util::escape_uri($uri);
  }

  $class->server->redirect($uri);
}

sub session { undef }
sub session_cookie_missing { shift->notes->session_cookie_missing(@_) }
sub session_cookie_munged  { shift->notes->session_cookie_munged(@_) }

sub apparently_not_accepting_cookies
{
  my($class) = shift;

  if($class->session_cookie_missing)
  {
    foreach my $uri ($class->referrer) #, $class->redirect_from)
    {
      next  unless $uri;

      my $uri = Rose::URI->new($uri);

      $uri->path(undef);
      $uri->query(undef);
      $uri->fragment(undef);
      $uri->host(lc $uri->host);

      $uri = $uri->as_string;

      my $insecure = $class->site_url_insecure;
      my $secure   = $class->site_url_secure;

      if($uri eq $insecure || $uri eq $secure)
      {
        return 1;
      }
    }
  }

  return 0;
}

sub message
{
  my($class, $param, $value) = @_;

  my $notes = $class->notes;

  my $messages = $notes->messages || {};

  if(@_ == 3)
  {
    $messages->{$param} = $value;
    $notes->messages($messages);
  }

  return $messages->{$param};
}

1;
