#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Test::More;

our %compare;

plan tests => (scalar keys %compare) + 2;

while(my($uri, $compare) = each(%compare))
{
  chomp(my $data = GET_BODY $uri);
  is($data, $compare, $uri);
}

#
# /rose/myapp/parts/nest/3
#

my $uri = '/rose/myapp/parts/nest/3';
chomp(my $data = GET_BODY $uri);
chomp(my $compare =<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };

<div class="error">
EOF
is(substr($data, 0, length($compare)), $compare, $uri);


#
# /rose/myapp/parts/nest/3
#

$uri = '/rose/myapp/parts/nest/3?error_mode=inline';
chomp($data = GET_BODY $uri);
chomp($compare =<<'EOF');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };

Execution of component '/rose/myapp/one_error.mc' failed!
EOF
is(substr($data, 0, length($compare)), $compare, $uri);

BEGIN
{
  our %compare =
  (
    '/rose/myapp' => <<'EOF',
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>

Testing 1 2 3.

</body>
</html>
EOF

    '/rose/myapp/parts/flat' => <<'EOF',
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };

<p>Two.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };
</p>
</body>
</html>
EOF

    '/rose/myapp/parts/nest/1' => <<'EOF',
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>
<p>Callone.mc:</p>

<p>&lt;&amp; 'one.mc' &amp;&gt; - <p>One.mc - ARGS = $VAR1 = {};

</p>

<p>$m-&gt;comp('one.mc') - <p>One.mc - ARGS = $VAR1 = {};

</p>
<p>Two.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };
</p>
</body>
</html>
EOF

    '/rose/myapp/parts/nest/2?a=123' => <<'EOF',
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::MP1::MyApp</title>
</head>
<body>
<p>Callapp.mc:</p>

<p>$app-&gt;do_parts_middle2() -
<p>Callone.mc:</p>

<p>&lt;&amp; 'one.mc' &amp;&gt; - <p>One.mc - ARGS = $VAR1 = {};

</p>

<p>$m-&gt;comp('one.mc') - <p>One.mc - ARGS = $VAR1 = {};

</p>
<p>Two.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };
</p>
</p>

<p>$app-&gt;show_comp('one'); -
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };

</p>

<p>$app-&gt;show_comp(name =&gt; 'one', comp_args =&gt; { foo =&gt; 6 }); -
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'foo' =&gt; 6,
          'message' =&gt; undef
        };

</p>

<p>$app-&gt;output_comp($app-&gt;root_uri . '/one.mc', foo =&gt; 7); -
<p>One.mc - ARGS = $VAR1 = {
          'foo' =&gt; 7
        };

</p>

<p>$app-&gt;show_comp(path =&gt; $app-&gt;root_uri . '/one.mc', foo =&gt; 7); -
<p>One.mc - ARGS = $VAR1 = {
          'error' =&gt; undef,
          'message' =&gt; undef
        };

</p>

<p>$app-&gt;param('a') = 123</p></body>
</html>
EOF
  );

  chomp for values %compare;
}
