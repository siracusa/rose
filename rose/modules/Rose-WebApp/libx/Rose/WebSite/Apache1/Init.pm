package Rose::WebSite::Apache::Init;

use strict;

use Apache;
use Apache::Constants qw(:response);

use Rose::WebSite;
use Rose::WebSite::User;
use Rose::WebSite::User::Auth;

use constant FAKE_AUTH => Apache->server->dir_config('RoseFakeAuth') || 0;

use constant USER_CLASS => Apache->server->dir_config('RoseUserClass') || 
                           'Rose::WebSite::User';
our $Debug = 0;

sub handler($$)
{
  my($class, $r) = @_;

  Rose::WebSite->update_request_number($r);

  my $uri = $r->uri();

  $Debug && $r->warn("$class getting uri $uri");

  #
  # Create web user object
  #

  my $user = $class->create_user();

  # Check authentication cookie
  if(my $auth = $user->auth_credentials)
  {
    my $vals = Rose::WebSite::User::Auth->decode_auth($auth);

    $user->username($vals->{'username'})  if(exists $vals->{'username'});
    $user->password($vals->{'password'})  if(exists $vals->{'password'});
  }
  elsif(FAKE_AUTH)
  {
    $user->username('fake_user');
    $user->password('fake_password');  
  }
  else
  {
    $user->is_anonymous(1);  
  }

  $Debug && $r->warn("$class setting user to ", 
                     (($user->is_anonymous) ? '(anonymous)' : 
                       q(') . $user->username . q(')));

  Rose::WebSite->user($user);
  Rose::WebSite->session($user->session);

  # Set referrer id, if any
  my %query = map { lc } $r->args;

  if($query{'refid'})
  {
    $query{'refid'} =~ s/\D+//g;

    if($query{'refid'})
    {
      $user->session->referrer_id($query{'refid'});
    }
  }

  return OK;
}

sub create_user
{
  my($self_or_class) = shift;

  my $user_class = USER_CLASS;
  return $user_class->new();
}

1;
