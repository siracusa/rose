package Rose::WebSite::Apache::Auth;

use strict;

use Apache;
use Apache::Constants qw(:response);

use Rose::WebSite;
use Rose::Apache::Notes;
use Rose::WebSite::User::Auth::Conf qw(%CONF);

use Rose::Apache::Module;
our @ISA = qw(Rose::Apache::Module);

our $Debug = 0;

sub handler($$)
{
  my($self, $r) = @_;

  $self = $self->new($r)  unless(ref($self));

  # Do not repeat authentication for sub-requests and internal redirects
  return DECLINED  unless($r->is_main);

  my $uri = $r->uri();

  my $notes    = $self->notes;
  my $orig_uri = $notes->untranslated_uri;

  $Debug && $r->warn("$self getting uri $uri (was $orig_uri)");

  # Exclude certain URLs from authentication process
  #return OK  if($orig_uri =~ /$CONF{'NO_AUTH_REGEX'}/o);

  my $user = Rose::WebSite->user;

  unless($user)
  {
    $r->log_reason("$self: user not set!");
    return FORBIDDEN;
  }

  $self->authenticate($user) || return FORBIDDEN;

  return OK;
}

sub authenticate
{
  my($self, $user) = @_;

  unless(ref $user && $user->isa('Rose::WebSite::User'))
  {
    Apache->request->log_error("$self: user '$user' is not an Rose::WebSite::User");
    return;
  }

  unless($user->is_logged_in or $user->is_anonymous)
  {
    if($user->login_is_expired)
    {
      Apache->request->warn('Login expired for user ' . $user->username);
      $user->logout;
      return 1;
    }
    else
    {
      unless($self->login(user => $user))
      {
        Apache->request->log_error($user->error)  if($user->error);
        #Apache->request->log_reason("$self: user is not logged in");
        $user->is_anonymous(1);
        return 1;
      }
    }
  }

  return 1;
}

sub login
{
  my($self_or_class, %args) = @_;

  my $r    = $args{'request'} || Apache->request;
  my $user = $args{'user'};

  my $notes = Rose::Apache::Notes->new;

  unless($user->login)
  {
    if($user->username =~ /\S/ || $user->password =~ /\S/)
    {
      $notes->login_error($user->nice_error);
      $r->log_reason($user->error);
    }

    return;
  }

  return 1;
}

sub logout
{
  my($self_or_class, %args) = @_;

  my $user = $args{'user'} || Rose::WebSite->user;

  unless($user->logout)
  {
    Apache->request->log_error($user->error)  if($user->error);
    return;
  }

  return 1;
}

1;
