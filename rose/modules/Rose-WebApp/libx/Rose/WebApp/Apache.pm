package Rose::WebSite;

use strict;

BEGIN
{
  if($ENV{'MOD_PERL'})
  {
    require Apache;
    require Apache::Cookie;
    require Apache::Constants;
    Apache::Constants->import(qw(REDIRECT));

    require HTML::Mason::ApacheHandler;
  }
  else
  {
    eval 'use constant REDIRECT => 302;'
  }
}

#use HTML::Mason::Interp;

use Rose::URI;
use Rose::Apache::Notes;

use Rose::HTML::Util;
use Rose::HTML::Image;

use Rose::WebSite::Apache::Trans;

use Rose::WebSite::Conf qw(%CONF);
use Rose::WebSite::Server::Conf qw(%SITE_CONF);
use Rose::WebSite::Server::Mason::Conf qw(%MASON_CONF);
use Rose::WebSite::User::Auth::Conf qw(%AUTH_CONF);

our $MASON_ERROR_MODE = ($ENV{'MOD_PERL'}) ? Apache->server->dir_config('MasonErrorMode') : '';
our $MASON_ERROR_FORMAT = ($MASON_ERROR_MODE eq 'fatal') ? 'text' : 'html';

our $Request_Number;

our $Debug = 0;

#
# Class data
#

use Class::MakeMethods::Template::ClassInherit
(
  scalar => 'error',
);

#
# Class methods
#

sub user    { shift->_notes('user', @_) }
sub session { shift->_notes('session', @_) }

sub session_cookie_missing { shift->_notes('session_cookie_missing', @_) }
sub session_cookie_munged  { shift->_notes('session_cookie_munged', @_)  }

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

      my $insecure = $class->server_url_insecure;
      my $secure   = $class->server_url_secure;

      if($uri eq $insecure || $uri eq $secure)
      {
        return 1;
      }
    }
  }

  return 0;
}

sub _notes
{
  my($class) = shift;
  my($param) = shift;

  my $notes = Rose::Apache::Notes->new();

  return $notes->$param(@_);
}

sub referrer_id
{
  my($class) = shift;

  if(my $session = $class->session)
  {
    return $session->referrer_id;
  }

  return undef;
}

sub message
{
  my($class, $param, $value) = @_;

  my $notes = Rose::Apache::Notes->new();

  my $messages = $notes->messages || {};

  if(@_ == 3)
  {
    $messages->{$param} = $value;
    $notes->messages($messages);
  }

  return $messages->{$param};
}

sub user_agent
{
  my($class, %args) = @_;
  my $r = $args{'apache_request'} || Apache->request;
  return $r->header_in('User-Agent') || $ENV{'HTTP_USER_AGENT'} || '';
}

sub user_agent_is_windows_ie  { $ENV{'HTTP_USER_AGENT'} =~ /\bMSIE \d/ }
sub user_agent_is_windows_ie5 { $ENV{'HTTP_USER_AGENT'} =~ /\bMSIE 5\./ }
sub user_agent_is_mac_ie      { $ENV{'HTTP_USER_AGENT'} =~ /\bMSIE \d\.\d+; Mac/ }
sub user_agent_is_mac_ie50    { $ENV{'HTTP_USER_AGENT'} =~ /\bMSIE 5\.0; Mac/ }

sub client_ip
{
  my($class, %args) = @_;

  my $r = $args{'apache_request'} || Apache->request;

  my $ip = $r->header_in('X-Forwarded-For') || $r->connection()->remote_ip() || '???';

  # Sometimes I get a comma-separated list like "63.110.43.226, 63.110.43.226"
  # Weird.  I'll just take the first address.
  $ip =~ s/^.*?\s*(\d+\.\d+\.\d+\.\d+).*/$1/;

  return $ip;
}

sub client_maximum_filename_length # excluding file name extension and "."
{
  my($class) = shift;

  my $ua = $class->user_agent;

  if($ua =~ /Win(?:dows)?\s*(?:NT|9[x0-9])|Mac OS X|Linux|[Dd]arwin/)
  {
    return 70;
  }

  return 27;
}

sub client_is_rose_internal
{
  ($_[0]->client_ip =~ m{^(?:192\.168\.124\.\d+|63\.110\.43\.22[69])$}) ? 1 : 0;
}

sub path_info
{
  my($class) = shift;

  if(@_)
  {
    return Apache->request->path_info($class->_notes('path_info' => $ENV{'PATH_INFO'} = shift));
  }

  return $ENV{'PATH_INFO'};
}

sub requested_uri
{
  my($class) = shift;

  my $uri = $class->_notes('requested_uri', @_);

  $uri ||= $ENV{$AUTH_CONF{'REQ_URI_COOKIE'}};

  return $uri || '/';
}

sub requested_uri_with_query
{
  my($class) = shift;

  my $uri   = $class->_notes('requested_uri');

  my $query = $class->_notes('requested_uri_query');

  $uri .= "?$query"  if(length $query);

  return $uri;
}

sub redirect_from
{
  my($class) = shift;

  my %args;

  if(@_ % 2 == 0)
  {
    %args = @_;
    @_= ();
  }

  my $uri = $class->_notes('redirect_from', @_);

  if(@_)
  {
    Apache->request->subprocess_env('Rose_REDIRECT_FROM' => $_[0]);
  }
  else
  {
    $uri ||= Apache->request->subprocess_env('Rose_REDIRECT_FROM');
  }

  unless(length($uri))
  {
    my $cookies = Apache::Cookie->fetch();

    if(my $cookie = $cookies->{$AUTH_CONF{'REQ_URI_COOKIE'}})
    {
      $uri = $cookie->value;
    }
    elsif(!$args{'ignore_referrer'})
    {
      $uri = Apache->request->header_in('Referer');
    }
  }

  return $uri;
}

sub referrer
{
  Apache->request->header_in('Referer') || $ENV{'HTTP_REFERER'};
}

sub post_login_uri 
{
  my($class) = shift;

  my $uri = $class->_notes('post_login_uri', @_);

  unless($uri)
  {
    my $cookies = Apache::Cookie->fetch();

    if(my $cookie = $cookies->{$AUTH_CONF{'POST_LOGIN_URI_COOKIE'}})
    {
      $uri = $cookie->value;
    }
  }

  return $uri;
}

sub requested_uri_query
{
  my($class) = shift;

  my $query = $class->_notes('requested_uri_query', @_);

  return $query;
}

sub mason_request { HTML::Mason::Request->instance }

sub is_secure
{
  my($class, %args) = @_;

  no warnings;

  return 0  unless($ENV{'MOD_PERL'});

  my $r = $args{'apache_request'} || Apache->request;
  return ($r->header_in('X-Forwarded-For-SSL') ||
          $r->header_in('X-Forwarded-For-Method') eq 'https') ? 1 : 0;
}

sub action_uri
{
  my($class, %args) = @_;

  return "$args{'root'}/$SITE_CONF{'ACTION_PATH'}/$args{'action'}";
}

sub action_path
{
  my($class, %args) = @_;

  return "$args{'root'}/$SITE_CONF{'ACTION_PATH'}/$args{'action'}$SITE_CONF{'ACTION_SUFFIX'}";
}

sub action_path_prefix { "/$SITE_CONF{'ACTION_PATH'}" }

sub app_path
{
  my($class, $app) = @_;

  return '/' . $app . $SITE_CONF{'APP_PATH'};
}

sub page_path
{
  my($class, $path) = @_;

  return Rose::WebSite::Apache::Trans->translate_uri(Apache->request, $path);

  #if($path !~ m{/\.\w+$})
  #{
  #  $path =~ s{/$}{};
  #  $path .= '/' . (substr($path, rindex($path, '/') + 1) || 'index') . '.html';
  #}
  #return $path;
}

sub page_uri
{
  my($class, $page) = @_;

  if($page =~ m{^(.*)([^/]+)/\2\.html$})
  {
    return "$1$2";
  }
  else
  {
    $page =~ s/\.html$//;
  }

  return $page;
}

sub server_url_secure   { $SITE_CONF{'SERVER_URL_SECURE'} }
sub server_url_insecure { $SITE_CONF{'SERVER_URL_INSECURE'} }

sub server_url
{
  ($_[0]->is_secure) ? $_[0]->server_url_secure :  
                       $_[0]->server_url_insecure;
}

sub site_url
{
  my($class, $path) = @_;

  return ($class->is_secure) ? $class->site_url_secure($path) :
                               $class->site_url_insecure($path);
}

sub site_url_secure
{
  my($class, $path) = @_;

  my $uri = Rose::URI->new($path || '');
  my $site_uri = Rose::URI->new($class->server_url_secure);

  $site_uri->path($uri->path);
  $site_uri->query($uri->query);
  $site_uri->fragment($uri->fragment);

  return $site_uri;
}

sub site_url_insecure
{
  my($class, $path) = @_;

  my $uri = Rose::URI->new($path || '');
  my $site_uri = Rose::URI->new($class->server_url_insecure);

  $site_uri->path($uri->path);
  $site_uri->query($uri->query);
  $site_uri->fragment($uri->fragment);

  return $site_uri;
}

sub current_url_secure
{
  my($class) = shift;
  my $url = $class->requested_uri;

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

  my $m = $class->mason_request;
  my $r = Apache->request;

  $m->clear_buffer  if($m);

  # Stop Apache from re-reading POSTed data (Mason bug)
  $r->method('GET');
  $r->headers_in->unset('Content-length');

  $r->content_type('text/html');

  # Escape clearly unescaped URIs
  if($uri =~ /\s/)
  {
    $uri = Rose::HTML::Util::escape_uri($uri);
  }

  #$r->headers_out->add(Referer  => $r->header_in('Referer'));
  $r->headers_out->add(Location => $uri);
  $r->status(REDIRECT);

  Rose::WebSite->session->store_if_modified;
  Rose::Apache::Notes->clear();

  $m->abort(REDIRECT)  if($m);
  Apache->request->send_http_header  if($class->in_app_context);
  Apache::exit();
}

sub internal_redirect
{
  my($class, $uri) = @_;

  my $m = $class->mason_request;
  my $r = Apache->request;

  $m->clear_buffer  if($m);

  # Stop Apache from re-reading POSTed data
  $r->method('GET');
  $r->headers_in->unset('Content-length');

  # Workaround for this bug:
  # http://www.masonhq.com/resources/todo/view.html?id=292
  $r->content_type('text/html');

  # Try to let the subprocess know where we're redirecting from
  $ENV{'Rose_REDIRECT_FROM'} = Rose::WebSite->requested_uri_with_query;
  $r->subprocess_env(Rose_REDIRECT_FROM => $ENV{'Rose_REDIRECT_FROM'});

  $Debug && warn "Internal redirect: $uri";

  Rose::WebSite->session->store_if_modified;

  $r->internal_redirect($uri);

  Apache->request->send_http_header  if($class->in_app_context);  
  $m->abort()  if($m);
  Apache::exit();
}

sub server_domain
{
  my $domain = $SITE_CONF{'SERVER_NAME'};
  $domain =~ s/.*\.([^.]+\.[^.]+\.?)$/.$1/;

  return $domain;
}

sub require_login
{
  my($class, %args) = @_;

  return 1  if(Rose::WebSite->user->is_logged_in);

  %args = (message => $_[1])  if(@_ == 2);

  my $r = Apache->request;

  my $domain = $class->server_domain;

  my $cookie = 
    Apache::Cookie->new($r, -name    => $AUTH_CONF{'REQ_URI_COOKIE'},
                            -value   => $class->requested_uri_with_query,
                            -domain  => $domain,
                            -path    => '/',
                            -expires => '+1min');

  $cookie->bake;

  my $post_login_uri = $args{'post_login_uri'};

  # Set or wipe post-login URI cookie
  $cookie = 
    Apache::Cookie->new($r, -name    => $AUTH_CONF{'POST_LOGIN_URI_COOKIE'},
                            -value   => $post_login_uri,
                            -domain  => $domain,
                            -path    => '/',
                            -expires => $post_login_uri ? '+1min' : '-1day');

  $cookie->bake;

  $class->post_login_uri($args{'post_login_uri'});
  $class->redirect_from($class->requested_uri_with_query);

  $class->message('login_required' => $args{'message'})
    if($args{'message'});

  $class->internal_redirect($AUTH_CONF{'LOGIN_URI'}); #$class->site_url_insecure($AUTH_CONF{'LOGIN_URI'}));
  return;
}

sub mason_interp
{
  my($class) = shift;

  if(my $m = HTML::Mason::Request->instance)
  {
    return $m->interp;
  }

  return $class->new_mason_interp;
}

our $Interp;

sub new_mason_interp
{
  $Interp ||=
  HTML::Mason::Interp->new(
    comp_root =>
    [
      [ docs => $MASON_CONF{'DOCUMENT_ROOT'} ],
      [ comps => "$MASON_CONF{'SERVER_ROOT'}/comps" ],
    ],
    data_dir      => "$MASON_CONF{'SERVER_ROOT'}/data",
    error_mode    => $MASON_ERROR_MODE,
    error_format  => $MASON_ERROR_FORMAT,
    allow_globals => [ qw($r $app) ]);
}

sub update_request_number
{
  my($class, $r) = @_;
  $r ||= Apache->request;
  $Request_Number++  if($r->is_initial_req);
  return $Request_Number;
}

sub request_number { $Request_Number }

sub in_app_context
{
  my($class, $r) = @_;
  $r ||= Apache->request;

  return ($r->dir_config('RoseAppClass')) ? 1 : 0;
}

sub image_html { shift->image(@_)->html }

sub image
{
  my($self) = shift;

  my(%args) = (@_ == 1) ? (src => $_[0]) : @_;

  return Rose::HTML::Image->new(%args);
}

1;

__END__
package jcs;

use Time::HiRes qw(gettimeofday);
our %track;

sub reset { %track = (); }
sub start
{
  my $where = (caller(1))[3];

  my $now = gettimeofday();
  print STDERR "JCS START $where\n";
  $track{$where}{'start'} = $track{$where}{'tick'} = $now;
}

sub tick
{
  my $where = (caller(1))[3];
  my $now = gettimeofday();
  print STDERR "JCS ", ($now - $track{$where}{'tick'}), " TICK $_[0] $where\n";
  $track{$where}{'tick'} = $now;
}

sub end
{
  my $where = (caller(1))[3];

  my $now = gettimeofday();
  $track{$where}{'end'} = $now;
  print STDERR "JCS ", ($now - $track{$where}{'start'}), " END $where\n";
}

1;
__END__

=head1 NAME

Rose::WebSite - Rose website class.

=head1 SYNOPSIS

    use Rose::WebSite;

    # Core objects
    $user  = Rose::WebSite->user;
    $m     = Rose::WebSite->mason_request;

    # Other objects
    $hat_image = Rose::WebSite->image('/images/hat.gif');
    print $hat_image->html;

    # Client information
    $ip = Rose::WebSite->client_ip;
    $ua = Rose::WebSite->user_agent;

    $uri = Rose::WebSite->requested_uri;

    # Abstracted URIs and paths
    $action_uri  = Rose::WebSite->action_uri('search/power');
    $action_path = Rose::WebSite->action_path('search/power');

    $page_path = Rose::WebSite->action_path('search/power');
    $app_path  = Rose::WebSite->action_path('search/power');

    $site_url = Rose::WebSite->site_url;

    # Redirects
    Rose::WebSite->redirect('/foo/bar');
    Rose::WebSite->internal_redirect('/foo/bar');

=head1 DESCRIPTION

L<Rose::WebSite> provides convenient access to "global" data via class methods.

=head1 CLASS METHODS

=over 4

=item B<action_path PATH>

Takes a relative path argument (e.g. 'search', 'login', 'search/power')
and returns the full path to the associated action file (e.g. '/bin/search.pl')
Note that action paths should never appear in links or any other user-visible
places.  They are mostly useful for explicitly loading components.  Example:

    $path = Rose::WebSite->action_path('search/power');
    $m->comp($path);

=item B<action_uri PATH>

Takes a relative path argument (e.g. 'search', 'login', 'search/power')
and returns the full path to the associated action URI (e.g. '/bin/search')

=item B<app_path PATH>

Takes a relative path argument (e.g. 'search', 'login', 'search/power')
and returns the full path to the associated application component URI
(e.g. '/bin/search/app.mc')  Note that application paths should never
appear in links or any other user-visible places.

=item B<client_ip>

Returns the client IP address.  That is, the (apparent) IP address of
the user that is currently accessing the site.

=item B<internal_redirect URI>

Redirects to URI without telling the client/browser.

=item B<mason_request>

Returns the current C<HTML::Mason::Request> request object.

=item B<page_path PATH>

Takes a relative path argument (e.g. 'search', 'login', 'search/power')
and returns the full path to the associated page component URI (e.g.
'/search/index.html')  Note that page paths should never appear in links
or any other user-visible places.

=item B<redirect URI>

Redirects the browser to URI using an "external" redirect (i.e. HTTP 302
status code). Calling C<redirect> effectively ends the processing of the
current request (by calling C<$m->abort>)

=item B<redirect_from>

If the current page was loaded due to an internal redirect, this method
returns the URI of the page that was redirected from.

=item B<requested_uri>

Returns the URI requested by the user/browser.  This is just the
path portion of the URI (e.g. "/foo/bar/baz")

=item B<requested_uri_query>

Returns the query portion of the URI requested by the user/browser 
(e.g. "foo=1&bar=2")

=item B<requested_uri_with_query>

Returns the URI requested by the user/browser, along with any query string.
(e.g. "/foo/bar/baz?a=1&b=2")

=item B<site_url PATH>

Returns the full URL to PATH on the site.  Example:

    # http://acme.whatever.com/foo
    $url = Rose::WebSite->site_url('/foo');

=item B<user>

The L<Rose::WebSite::User> object for the current user.

=item B<user_agent>

The client web browser's user agent string.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)
