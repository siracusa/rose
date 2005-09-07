#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Test::More;

plan tests => 1;

chomp(my $data = GET_BODY '/rose/webapp/features/appparams?a=bar;APP_a=hello;b=bye');
chomp(my $compare =<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::WebApp::Features::WithAppParams</title>
</head>
<body>

$app-&gt;app_param('a') = hello<br/>
$app-&gt;app_param_exists('a') = 1<br/>
$app-&gt;app_param_exists('b') = <br/>

</body>
</html>
EOF
is($data, $compare, '/rose/webapp/features/appparams?a=bar;APP_a=hello;b=bye');
