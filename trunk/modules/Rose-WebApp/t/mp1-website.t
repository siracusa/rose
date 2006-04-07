#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Apache::TestUtil;
use Test::More;

plan tests => 2;

my $data = GET_BODY '/rose/website?a=1&b=2&c=3&c=4';
chomp(my $compare=<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::WebSite</title>
</head>
<body>

<a href="/rose/website?foo=123">Link to self</a><br>
<a href="/rose/website/redirect">Redirect</a><br>
Server: Rose::WebApp::Server<br>
Referrer: <br>
site_host_secure: localhost<br>
site_host_insecure: localhost<br>
site_port_secure: 443<br>
site_port_insecure: 8529<br>
site_host: localhost<br>
site_port: 8529<br>
site_url_secure: https://localhost<br>
site_url_insecure: http://localhost:8529<br>
site_url: http://localhost:8529<br>
current_url_secure: https://localhost/rose/website?a=1&amp;b=2&amp;c=3&amp;c=4<br>
current_url_insecure: http://localhost:8529/rose/website?a=1&amp;b=2&amp;c=3&amp;c=4<br>
site_domain_insecure: localhost<br>
site_domain_secure: localhost<br>
site_domain: localhost<br>
site_url_secure('/foo?a=1'): https://localhost/foo?a=1<br>
site_url_insecure('/foo?a=1'): http://localhost:8529/foo?a=1<br>
Args: a=1&amp;b=2&amp;c=3&amp;c=4<br>
Path Info: <br>
Req URI: /rose/website<br>
Req URI Query: a=1&amp;b=2&amp;c=3&amp;c=4<br>
Req URI With Query: /rose/website?a=1&amp;b=2&amp;c=3&amp;c=4<br>
Referrer: <br>
Secure: 0<br>
</body></html>
EOF
is($data, $compare, 'a=1&b=2&c=3&c=4');

$data = GET_BODY '/rose/website/foo/bar?a=1&b=2&c=3&c=4';
chomp($compare=<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::WebSite</title>
</head>
<body>

<a href="/rose/website?foo=123">Link to self</a><br>
<a href="/rose/website/redirect">Redirect</a><br>
Server: Rose::WebApp::Server<br>
Referrer: <br>
site_host_secure: localhost<br>
site_host_insecure: localhost<br>
site_port_secure: 443<br>
site_port_insecure: 8529<br>
site_host: localhost<br>
site_port: 8529<br>
site_url_secure: https://localhost<br>
site_url_insecure: http://localhost:8529<br>
site_url: http://localhost:8529<br>
current_url_secure: https://localhost/rose/website/foo/bar?a=1&amp;b=2&amp;c=3&amp;c=4<br>
current_url_insecure: http://localhost:8529/rose/website/foo/bar?a=1&amp;b=2&amp;c=3&amp;c=4<br>
site_domain_insecure: localhost<br>
site_domain_secure: localhost<br>
site_domain: localhost<br>
site_url_secure('/foo?a=1'): https://localhost/foo?a=1<br>
site_url_insecure('/foo?a=1'): http://localhost:8529/foo?a=1<br>
Args: a=1&amp;b=2&amp;c=3&amp;c=4<br>
Path Info: /foo/bar<br>
Req URI: /rose/website/foo/bar<br>
Req URI Query: a=1&amp;b=2&amp;c=3&amp;c=4<br>
Req URI With Query: /rose/website/foo/bar?a=1&amp;b=2&amp;c=3&amp;c=4<br>
Referrer: <br>
Secure: 0<br>
</body></html>
EOF
is($data, $compare, '/foo/bar?a=1&b=2&c=3&c=4');
