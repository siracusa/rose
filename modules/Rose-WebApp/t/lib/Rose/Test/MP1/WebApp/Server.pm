package Rose::Test::MP1::WebApp::Server;

use strict;

use Apache::Util qw(escape_html);

use Rose::WebApp::Server;

use Apache::Constants qw(:response);

sub handler
{
  my($r) = shift;

  my $s = Rose::WebApp::Server->new(apache_request => $r);
  $s->update_request_id;

  $r->content_type('text/html');
  $r->send_http_header;

  $r->no_cache(1);

  $r->print(<<"EOF");
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::Apache1</title>
</head>
<body>
EOF

  $r->print('Request: ', escape_html($s->apache_request), "<br>\n");
  $r->print('Notes: ', escape_html($s->notes), "<br>\n");
  $r->print('UA: ', escape_html($s->user_agent), "<br>\n");
  $r->print('IP: ', escape_html($s->client_ip), "<br>\n");
  $r->print('Path Info: ', escape_html($s->path_info), "<br>\n");
  $r->print('Req URI: ', escape_html($s->requested_uri), "<br>\n");
  $r->print('Req URI Query: ', escape_html($s->requested_uri_query), "<br>\n");
  $r->print('Req URI With Query: ', escape_html($s->requested_uri_with_query), "<br>\n");
  $r->print('Referrer: ', escape_html($s->referrer), "<br>\n");
  $r->print('Secure: ', escape_html($s->is_secure), "<br>\n");
  $r->print('Req Id: ', escape_html($s->request_id), "<br>\n");

  $r->print('</body></html>');

  return OK;
}

1;