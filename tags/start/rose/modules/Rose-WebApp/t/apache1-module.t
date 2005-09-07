#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Apache::TestUtil;
use Test::More;

plan tests => 3;

my $data = GET_BODY '/rose/apache1/module?a=1&b=2';
chomp(my $compare=<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::Apache1::Module</title>
</head>
<body>
Params: <pre>$VAR1 = {
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: a, b<br>
Param Values: <pre>$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(z): <br>
delete_param('c')<br>Params: <pre>$VAR1 = {
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: a, b<br>
Param Values: <pre>$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(c): <br>
</body></html>
EOF
is($data, $compare, 'a=1&b=2');

$data = GET_BODY '/rose/apache1/module?a=1;b=2';
chomp($compare=<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::Apache1::Module</title>
</head>
<body>
Params: <pre>$VAR1 = {
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: a, b<br>
Param Values: <pre>$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(z): <br>
delete_param('c')<br>Params: <pre>$VAR1 = {
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: a, b<br>
Param Values: <pre>$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(c): <br>
</body></html>
EOF
chomp($compare);
is($data, $compare, 'a=1;b=2');


$data = GET_BODY '/rose/apache1/module?a=1;b=2;c=3;c=4';
chomp($compare=<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::Apache1::Module</title>
</head>
<body>
Params: <pre>$VAR1 = {
          'c' =&gt; [
                   '3',
                   '4'
                 ],
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: c, a, b<br>
Param Values: <pre>$VAR1 = [
          '3',
          '4'
        ];

$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(z): <br>
delete_param('c')<br>Params: <pre>$VAR1 = {
          'a' =&gt; '1',
          'b' =&gt; '2'
        };
</pre><br>
Param Names: a, b<br>
Param Values: <pre>$VAR1 = '1';

$VAR1 = '2';
</pre><br>
Param Exists(a): 1<br>
Param Exists(c): <br>
</body></html>
EOF
is($data, $compare, 'a=1;b=2;c=3;c=4');

