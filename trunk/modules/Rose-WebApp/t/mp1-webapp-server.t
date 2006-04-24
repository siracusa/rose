#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Apache::TestUtil;
use Test::More;

plan tests => 44;

my $i = 0;

$_ = GET_BODY '/rose/webapp/server'; $i++;

ok(m{^Request: Apache=SCALAR\(0x[\da-f]+\)<br>$}m, "request $i");
ok(m{^Notes: Rose::WebApp::Server::Notes=HASH\(0x[\da-f]+\)<br>$}m, "notes $i");
ok(m{^UA: .*<br>$}m, "ua $i");
ok(m{^IP: 127\.0\.0\.1<br>$}m, "ip $i");
ok(m{^Path Info: <br>$}m, "path info $i");
ok(m{^Req URI: /rose/webapp/server<br>$}m, "req uri $i");
ok(m{^Req URI Query: <br>$}m, "req uri query $i");
ok(m{^Req URI With Query: /rose/webapp/server<br>$}m, "req uri with query $i");
ok(m{^Referrer: <br>$}m, "referrer $i");
ok(m{^Secure: 0<br>$}m, "secure $i");
ok(m{^Req Id: \d+:\d+<br>$}m, "req id $i");

$_ = GET_BODY "/rose/webapp/server?a=1&b=2"; $i++;

ok(m{^Request: Apache=SCALAR\(0x[\da-f]+\)<br>$}m, "request $i");
ok(m{^Notes: Rose::WebApp::Server::Notes=HASH\(0x[\da-f]+\)<br>$}m, "notes $i");
ok(m{^UA: .*<br>$}m, "ua $i");
ok(m{^IP: 127\.0\.0\.1<br>$}m, "ip $i");
ok(m{^Path Info: <br>$}m, "path info $i");
ok(m{^Req URI: /rose/webapp/server<br>$}m, "req uri $i");
ok(m{^Req URI Query: a=1&amp;b=2<br>$}m, "req uri query $i");
ok(m{^Req URI With Query: /rose/webapp/server\?a=1&amp;b=2<br>$}m, "req uri with query $i");
ok(m{^Referrer: <br>$}m, "referrer $i");
ok(m{^Secure: 0<br>$}m, "secure $i");
ok(m{^Req Id: \d+:\d+<br>$}m, "req id $i");

$_ = GET_BODY "/rose/webapp/server?a=1;b=2"; $i++;

ok(m{^Request: Apache=SCALAR\(0x[\da-f]+\)<br>$}m, "request $i");
ok(m{^Notes: Rose::WebApp::Server::Notes=HASH\(0x[\da-f]+\)<br>$}m, "notes $i");
ok(m{^UA: .*<br>$}m, "ua $i");
ok(m{^IP: 127\.0\.0\.1<br>$}m, "ip $i");
ok(m{^Path Info: <br>$}m, "path info $i");
ok(m{^Req URI: /rose/webapp/server<br>$}m, "req uri $i");
ok(m{^Req URI Query: a=1;b=2<br>$}m, "req uri query $i");
ok(m{^Req URI With Query: /rose/webapp/server\?a=1;b=2<br>$}m, "req uri with query $i");
ok(m{^Referrer: <br>$}m, "referrer $i");
ok(m{^Secure: 0<br>$}m, "secure $i");
ok(m{^Req Id: \d+:\d+<br>$}m, "req id $i");

$_ = GET_BODY "/rose/webapp/server/foo/bar?a=1;b=2"; $i++;

ok(m{^Request: Apache=SCALAR\(0x[\da-f]+\)<br>$}m, "request $i");
ok(m{^Notes: Rose::WebApp::Server::Notes=HASH\(0x[\da-f]+\)<br>$}m, "notes $i");
ok(m{^UA: .*<br>$}m, "ua $i");
ok(m{^IP: 127\.0\.0\.1<br>$}m, "ip $i");
ok(m{^Path Info: /foo/bar<br>$}m, "path info $i");
ok(m{^Req URI: /rose/webapp/server/foo/bar<br>$}m, "req uri $i");
ok(m{^Req URI Query: a=1;b=2<br>$}m, "req uri query $i");
ok(m{^Req URI With Query: /rose/webapp/server/foo/bar\?a=1;b=2<br>$}m, "req uri with query $i");
ok(m{^Referrer: <br>$}m, "referrer $i");
ok(m{^Secure: 0<br>$}m, "secure $i");
ok(m{^Req Id: \d+:\d+<br>$}m, "req id $i");

