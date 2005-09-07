package Rose::WebSite::Apache::Trans;

use strict;

BEGIN
{
  if($ENV{'MOD_PERL'})
  {
    require Apache::Constants;
    Apache::Constants->import(qw(:response));
  }
  else { eval 'use constant DECLINED => -1;' }
}

use Rose::URI;

use Rose::WebSite;

use Rose::Apache::Notes;

use Rose::WebSite::Server::Conf qw(%SERVER_CONF);
use Rose::WebSite::User::Auth::Conf qw(%AUTH_CONF);

our $DOC_ROOT;

our $Debug = 0;

sub handler($$)
{
  my($class, $r) = @_;

  my $uri = $r->uri();

  $Debug && $r->warn(__PACKAGE__, " getting uri $uri");

  my $notes = Rose::Apache::Notes->new();

  if($ENV{'Rose_REDIRECT_FROM'})
  {
    $notes->redirect_from($ENV{'Rose_REDIRECT_FROM'});
  }

  if($r->is_main)
  {
    $notes->requested_uri($uri);
    $notes->requested_uri_query(scalar $r->args);

    $notes->untranslated_uri($uri);
  }

  my $new_uri = $class->translate_uri($r, $uri, 1);

  if($new_uri)
  {
    $Debug && $r->warn(__PACKAGE__, " setting $r->uri to $new_uri\n");
    $r->uri($new_uri);
  }

  return DECLINED;
}

sub translate_uri
{
  my($class, $r, $uri, $transhandler) = @_;

  # Relative URIs are not translated
  return $uri  unless(index($uri, '/') == 0);

  # Don't translate if this location is handled by an app
  return $uri  if($r->is_main && $r->dir_config('RoseAppClass') && $transhandler);

  # Check for a URI handler
  #if($uri =~ /^($URI_HANDLERS_RE)(.*)/o)
  #{
  #  my $handler = $URI_HANDLERS{$1} or die "Missing URI handler for '$uri'";
  #  $Debug && $r->warn(__PACKAGE__, " set path info = $2");
  #  Rose::WebSite->path_info($2 || '');
  #  $Debug && $r->warn(__PACKAGE__, "set URI handler = $handler");
  #  $uri = $handler;
  #}

  # Add $SERVER_CONF{'ACTION_SUFFIX'} (usually '.pl') to "action paths"
  #if($uri =~ m{/$SERVER_CONF{'ACTION_PATH'}/}o &&
  #   $uri !~ /\Q$SERVER_CONF{'ACTION_SUFFIX'}\E$/o)
  #{
  #  $uri .= $SERVER_CONF{'ACTION_SUFFIX'};
  #  $Debug && warn(__PACKAGE__, " setting uri to $uri");
  #}

  $DOC_ROOT ||= $r->document_root;

  # Handle directories to avoid pnotes-destroying internal redirects
  # Directory index matches the directory name, to avoid the proliferation
  # of index.html files
  if(-d $DOC_ROOT . $uri)
  {
    # Given /foo/bar/baz, $dir = 'baz'
    my $dir = (substr($uri, rindex($uri, '/') + 1) || 'index') . '.html';

    $uri .= '/'  unless($uri =~ m{/$});
    $uri .= $dir;
    $Debug && $r->warn(__PACKAGE__, " handle dir: $uri");
  }
  # Otherwise tack on a '.html' if there is no extension
  elsif($uri !~ /\.\w+$/)
  {
    $uri =~ s{/$}{};
    $uri .= '.html';
  }

  return $uri;
}

1;

# This was used before app objects were in charge of dispatch.
# In the httpd.conf file, there'd be something like this:
#
# PerlSetVar RoseURIHandlers  "/products/special, /products, /foo => /foobar, /bar => /foobar"
# 
# Then this code would go near teh top of this file.
#
# our(%URI_HANDLERS, $URI_HANDLERS_RE);
# 
# if(my $handlers =  Apache->server->dir_config('RoseURIHandlers'))
# {
#   for($handlers) { s/^\s+//; s/\s+$//; s/\s*=>\s*/=>/g; s/\s+/ /g; }
# 
#   my @handlers;
# 
#   foreach my $handler (split(/\s+|\s*,\s*/, $handlers))
#   {
#     if($handler =~ /^(.+)=>(.+)$/)
#     {
#       $URI_HANDLERS{$1} = $2;
#       push(@handlers, $1);
#     }
#     else
#     {
#       $URI_HANDLERS{$handler} = $handler;
#       push(@handlers, $handler);
#     }
#   }
# 
#   $URI_HANDLERS_RE = join('|', map { quotemeta } 
#                                sort { length($b) <=> length($a) } @handlers);
# }
