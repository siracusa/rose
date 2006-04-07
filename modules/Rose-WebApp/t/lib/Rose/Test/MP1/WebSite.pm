package Rose::Test::MP1::WebSite;

use strict;

use Apache::Util qw(escape_html);

use Rose::WebSite;

use Apache::Constants qw(:response);

sub handler
{
  my($r) = shift;

  if($r->uri =~ m{/redirect$})
  {
    Rose::WebSite->redirect('/rose/website?rf=' . Rose::WebSite->request_id);   
  }

  if($r->uri =~ m{/internal_redirect$})
  {
    Rose::WebSite->internal_redirect('/rose/website?intredir=' . Rose::WebSite->request_id);   
  }

  $r->content_type('text/html');
  $r->send_http_header;

  $r->no_cache(1);

  $r->print(<<"EOF");
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::WebSite</title>
</head>
<body>

<a href="/rose/website?foo=123">Link to self</a><br>
<a href="/rose/website/redirect">Redirect</a><br>
EOF

  $r->print('Server: ', escape_html(ref Rose::WebSite->server), "<br>\n");
  $r->print('Referrer: ', escape_html(Rose::WebSite->referrer), "<br>\n");

  foreach my $method (qw(site_host_secure site_host_insecure site_port_secure
                         site_port_insecure site_host site_port site_url_secure 
                         site_url_insecure site_url current_url_secure 
                         current_url_insecure site_domain_insecure site_domain_secure
                         site_domain))
  {
    no strict 'refs';
    $r->print("$method: ", escape_html(Rose::WebSite->$method()), "<br>\n");
  }

  $r->print("site_url_secure('/foo?a=1'): ", escape_html(Rose::WebSite->site_url_secure('/foo?a=1')), "<br>\n");
  $r->print("site_url_insecure('/foo?a=1'): ", escape_html(Rose::WebSite->site_url_insecure('/foo?a=1')), "<br>\n");

  $r->print('Args: ', escape_html(scalar $r->args), "<br>\n");

  $r->print('Path Info: ', escape_html(Rose::WebSite->path_info), "<br>\n");
  $r->print('Req URI: ', escape_html(Rose::WebSite->requested_uri), "<br>\n");
  $r->print('Req URI Query: ', escape_html(Rose::WebSite->requested_uri_query), "<br>\n");
  $r->print('Req URI With Query: ', escape_html(Rose::WebSite->requested_uri_with_query), "<br>\n");
  $r->print('Referrer: ', escape_html(Rose::WebSite->referrer), "<br>\n");
  $r->print('Secure: ', escape_html(Rose::WebSite->is_secure), "<br>\n");
  #$r->print('Req Id: ', escape_html(Rose::WebSite->request_id), "<br>\n");

  $r->print('</body></html>');

  return OK;
}

1;