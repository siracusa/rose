package Rose::Test::Apache1;

use strict;

use Apache::Util qw(escape_html);

use Rose::Apache;

use Apache::Constants qw(:response);

sub handler
{
  my($r) = shift;

  my $ap = Rose::Apache->new(request => $r);
  $ap->update_request_id;

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

  $r->print('Request: ', escape_html($ap->request), "<br>\n");
  $r->print('Notes: ', escape_html($ap->notes), "<br>\n");
  $r->print('UA: ', escape_html($ap->user_agent), "<br>\n");
  $r->print('IP: ', escape_html($ap->client_ip), "<br>\n");
  $r->print('Path Info: ', escape_html($ap->path_info), "<br>\n");
  $r->print('Req URI: ', escape_html($ap->requested_uri), "<br>\n");
  $r->print('Req URI Query: ', escape_html($ap->requested_uri_query), "<br>\n");
  $r->print('Req URI WIth Query: ', escape_html($ap->requested_uri_with_query), "<br>\n");
  $r->print('Referrer: ', escape_html($ap->referrer), "<br>\n");
  $r->print('Secure: ', escape_html($ap->is_secure), "<br>\n");
  $r->print('Req Id: ', escape_html($ap->request_id), "<br>\n");

  $r->print('</body></html>');

  return OK;
}

1;