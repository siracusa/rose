#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Apache::TestUtil;
use Test::More;

plan tests => 6;

my $i = 0;

$_ = GET_BODY '/rose/apache1/notes'; $i++;

ok(m{^foo:f(\d+):1<br>$}m, "foo $i");
my $f1 = $1;
ok(m{^bar:b(\d+):1<br>$}m, "bar $i");
my $b1 = $1;

$_ = GET_BODY '/rose/apache1/notes'; $i++;

ok(m{^foo:f(\d+):1<br>$}m, "foo $i");
my $f2 = $1;
ok(m{^bar:b(\d+):1<br>$}m, "bar $i");
my $b2 = $1;

ok($f1 != $f2, 'f1 != f2');
ok($b1 != $b2, 'f1 != f2');
