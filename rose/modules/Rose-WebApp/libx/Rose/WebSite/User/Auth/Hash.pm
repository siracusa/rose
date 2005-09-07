package Rose::WebSite::User::Auth::Hash;

use strict;

use MIME::Base64;
use Digest::SHA1 qw(sha1);

use Apache::Util qw(escape_uri unescape_uri);

use constant HASH_SEP => ':';

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
    my $hash = $class->create_auth_credentials($user);

    unless($hash eq $auth)
    {
      $class->error("$class: User auth invalid");
      return 0;
    }
  }
  else
  {
    $class->error("$class: User auth not set");
    return 0;
  }

  return 1;
}

sub encode_auth
{
  my($class, $params) = @_;

  my $cookie = join(';', map { $_ . '=' . escape_uri($params->{$_}) }
                         qw(username));

  my $data = join(';', map { $_ . '=' . escape_uri($params->{$_}) }
                       sort keys(%$params));

  #$Debug && warn "$class: encode_auth - ", 
  #          encode_base64(join(HASH_SEP, sha1($data), $cookie), ''), "\n";
  return encode_base64(join(HASH_SEP, sha1($data), $cookie), '');
}

sub decode_auth
{
  my($class, $cookie) = @_;

  $cookie = decode_base64($cookie);

  # Trim hash portion and separator
  substr($cookie, 0, index($cookie, HASH_SEP) + 1) = '';

  my %vals = map { unescape_uri($_) } map { split('=', $_, 2) } split(';', $cookie);

  #$Debug && warn "$class: decode_auth - ", Data::Dumper::Dumper(\%vals);
  return \%vals;
}

1;
