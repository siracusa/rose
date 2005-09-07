package Rose::WebSite::User::Auth::Crypt;

use strict;

use MIME::Base64;

use Apache::Util qw(escape_uri unescape_uri);

use Rose::WebSite::Crypt;

require Rose::WebSite::User::Auth;

our $Debug = undef;

our $Error;

sub error
{
  my($class) = shift;

  return $Error = $_[0]  if(@_);
  return $Error;
}

sub check_auth_credentials
{
  my($class, $user) = @_;

  $Error = undef;

  unless(ref $user && $user->isa('Rose::WebSite::User'))
  {
    $class->error("$class: user '$user' is not a Rose::WebSite::User");
    return 0;
  }

  my $auth = $user->auth_credentials;

  if($auth)
  {
    my $vals = $class->decode_auth($auth);

    unless($vals->{'ip'} eq Rose::WebSite->client_ip)
    {
      my $ip = Rose::WebSite->client_ip;
      $class->error("$class: User auth IP address does not match client IP: '$vals->{'ip'}' ne '$ip'");
      return 0;
    }

    unless($vals->{'ua'} eq Rose::WebSite->user_agent)
    {
      my $ua = Rose::WebSite->user_agent;
      $class->error("$class: User auth user agent does not match client user agent: '$vals->{'ua'}' ne '$ua'");
      return 0;
    }
  }
  else
  {
    $class->error("$class: User auth not set");
    return;
  }

  return 1;
}

sub encode_auth
{
  my($class, $params) = @_;

  my $cookie = join(';', map { $_ . '=' . escape_uri($params->{$_}) }
                         sort keys(%$params));

  return encode_base64(Rose::WebSite::Crypt->encrypt($cookie), '');
}

sub decode_auth
{
  my($class, $cookie) = @_;

  my $val = Rose::WebSite::Crypt->decrypt(decode_base64($cookie)) || return {};

  my %vals = map { unescape_uri($_) } map { split('=', $_, 2) } split(';', $val);

  return \%vals;
}

1;
