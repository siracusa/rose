package Rose::WebSite::User::Session::Generate::SHA1;

use strict;

use Apache;
use Digest::SHA1;

use Rose::WebSite;

use constant ID_SUFFIX        => 'Rose';
use constant ID_SUFFIX_LENGTH => length(ID_SUFFIX);
use constant ID_BODY_LENGTH   => 40;
use constant ID_LENGTH        => ID_BODY_LENGTH + ID_SUFFIX_LENGTH;

sub generate
{
  my($session) = shift;

  $session->{'data'}{'_session_id'} =
    Digest::SHA1::sha1_hex(time(). {}. rand(). $$) . ID_SUFFIX;
}

sub validate
{
  my($session) = shift;

  my $id = $session->{'data'}->{'_session_id'};

  if(length($id) != ID_LENGTH || index($id, ID_SUFFIX) != ID_BODY_LENGTH ||
     substr($id, 0, ID_BODY_LENGTH) !~ /^[a-fA-F0-9]+$/)
  {
    Rose::WebSite->session_cookie_munged($id || 1);

    Apache->request->log_error('Got invalid session id from client ' . 
      Rose::WebSite->client_ip . " - '$id'");

    die "Invalid session id";
  }

  return 1;
}

1;
