package Rose::Test::MP1::WebApp::Server::Notes;

use strict;

use Data::Dumper;

use Apache::Util qw(escape_html);

use Rose::WebApp::Server::Notes;

use Apache::Constants qw(:response);

our $Num = 1;

sub handler
{
  my($r) = shift;

  my $notes = Rose::Apache::Notes->new;

  $notes->foo('f' . int(rand(10000)) . ':' . $Num);
  $notes->bar('b' . int(rand(10000)) . ':' . $Num);

  $r->content_type('text/html');
  $r->send_http_header;

  $r->no_cache(1);

  $r->print(<<"EOF");
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::WebApp::Server::Notes</title>
</head>
<body>
EOF

  $r->print('foo:', escape_html($notes->foo || ''), "<br>\n");
  $r->print('bar:', escape_html($notes->bar || ''), "<br>\n");

  $r->print('</body></html>');

  return OK;
}

1;
