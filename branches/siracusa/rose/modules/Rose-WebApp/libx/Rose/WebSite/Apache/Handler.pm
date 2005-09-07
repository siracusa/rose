package Rose::WebSite::Apache::Handler;

use strict;

use HTML::Mason::ApacheHandler;

use Rose::WebSite;
use Rose::Apache::Notes;

use Rose::WebSite::Server::Mason::Conf qw(%MASON_CONF);

our $AH;

sub handler($$)
{
  my($class, $r) = @_;

  $AH ||= HTML::Mason::ApacheHandler->new(
            comp_root =>
            [
              [ docs  => $MASON_CONF{'DOCUMENT_ROOT'} ],
              [ comps => "$MASON_CONF{'SERVER_ROOT'}/comps" ],
            ],
            data_dir => "$MASON_CONF{'SERVER_ROOT'}/data");

  my $ret = $AH->handle_request($r);

  Rose::Apache::Notes->clear();

  return $ret;
}

1;
