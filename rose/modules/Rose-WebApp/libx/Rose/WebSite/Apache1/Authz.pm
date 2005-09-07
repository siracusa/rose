package Rose::WebSite::Apache::Authz;

use strict;

use Apache::Constants qw(:common);

use Rose::Apache::Notes;
use Rose::WebSite::User::Auth::Conf qw(%CONF);

use constant FAKE_AUTH => Apache->server->dir_config('RoseFakeAuth');

our $Debug = 0;

sub handler($$)
{
  my($class, $r) = @_;

  return DECLINED  unless($r->is_main());

  my $uri = $r->uri();

  my $notes    = Rose::Apache::Notes->new();
  my $orig_uri = $notes->untranslated_uri;

  $Debug && $r->warn("$class getting uri $uri (was $orig_uri)");

  return OK  if($orig_uri =~ /$CONF{'NO_AUTHZ_REGEX'}/io);

  my $user = $notes->user;

  if($class->authorize($user))
  {
    $Debug && $r->warn("$class - authz OK");
    return OK;
  }

  $Debug && $r->warn("$class - authz FORBIDDEN");
  return FORBIDDEN;
}

sub authorize
{
  my($class, $user) = @_;

  return 1;
}

1;
