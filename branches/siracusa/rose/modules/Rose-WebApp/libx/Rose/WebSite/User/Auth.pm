package Rose::WebSite::User::Auth;

use strict;

use MIME::Base64;

use Apache::Util qw(escape_uri unescape_uri);

use Rose::WebSite;

my $Auth = Apache->server->dir_config('RoseUserAuth');

our @ISA;

our $Debug = undef;

sub import
{
  # This is a sort of crazy form of "delegation through inheritance"
  # It saves  a bit of memory by not having to keep an object around
  # to delegate to.
  unless(@ISA)
  {
    if(lc $Auth eq 'crypt')
    {
      require Rose::WebSite::User::Auth::Crypt;
      @ISA = qw(Rose::WebSite::User::Auth::Crypt);
    }
    else
    {
      require Rose::WebSite::User::Auth::Hash;
      @ISA = qw(Rose::WebSite::User::Auth::Hash);
    }
  }
}

sub create_auth_credentials
{
  my($class, $user) = @_;

  unless(ref $user && $user->isa('Rose::WebSite::User'))
  {
    $class->error("$class: user '$user' is not an Rose::WebSite::User");
    return;
  }

  my %vals;

  $vals{'user_id'}  = $user->user_id;
  $vals{'username'} = $user->username;
  $vals{'password_encrypted'} = $user->password_encrypted;

  $vals{'ip'} = Rose::WebSite->client_ip;
  $vals{'ua'} = Rose::WebSite->user_agent;

  return $class->encode_auth(\%vals);
}

1;
