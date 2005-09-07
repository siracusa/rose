#!/usr/bin/perl -w

use strict;

use Test::More tests => 24;

BEGIN
{
  use_ok('Rose::URI');
}

my $uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
ok(ref $uri eq 'Rose::URI' && $uri eq 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'Parse full URI (&)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1;a=2;b=3#blah');
ok(ref $uri eq 'Rose::URI' && $uri eq 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'Parse full URI (;)');

is($uri->scheme,   'http', 'scheme()');
is($uri->username, 'un', 'username()');
is($uri->password, 'pw', 'password()');
is($uri->host,     'ob.com', 'host()');
is($uri->port,     '81', 'port()');
is($uri->path,     '/bar/baz', 'path()');
is($uri->query,    'a=1&a=2&b=3', 'query()');
is($uri->fragment, 'blah', 'fragment()');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->abs, 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'abs() (simple)');

$uri = Rose::URI->new('/bar/baz?a=1&a=2&b=3#blah');
is($uri->abs('http://ob.com:81/'), 'http://ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'abs() (with base 1)');

$uri = Rose::URI->new('/bar/baz?a=1&a=2&b=3#blah');
is($uri->abs('http://ob.com:81'), 'http://ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'abs() (with base 2)');

$uri = Rose::URI->new('bar/baz?a=1&a=2&b=3#blah');
is($uri->abs('http://ob.com:81'), 'http://ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'abs() (with base 3)');

$uri = Rose::URI->new('bar/baz?a=1&a=2&b=3#blah');
is($uri->abs('http://ob.com:81/'), 'http://ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'abs() (with base 4)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel, 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'rel (no base)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel('http://un:pw@ob.com:81/'), 'bar/baz?a=1&a=2&b=3#blah', 'rel (good base 1)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel('http://un:pw@ob.com:81'), 'bar/baz?a=1&a=2&b=3#blah', 'rel (good base 2)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel('http://ob.com:81'), 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'rel (bad base 1)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel('http://un:pw@ob.com/'), 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'rel (bad base 2)');

$uri = Rose::URI->new('http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah');
is($uri->rel('http://un:pw@ob.com:82/'), 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3#blah', 'rel (bad base 3)');

$uri->query_param(c => '1 + 1 = 2');
is($uri, 'http://un:pw@ob.com:81/bar/baz?a=1&a=2&b=3&c=1%20%2B%201%20%3D%202#blah', 'escape 1');

$uri->path('/Foo Bar/Baz');
$uri->username('u/n&');
$uri->query_param(c => '?5/1 + 1-3 = 2_()');

is($uri, 'http://u%2Fn%26:pw@ob.com:81/Foo%20Bar/Baz?a=1&a=2&b=3&c=%3F5%2F1%20%2B%201-3%20%3D%202_()#blah', 'escape 2');
