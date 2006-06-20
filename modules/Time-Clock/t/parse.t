#!/usr/bin/perl -w

use strict;

use Test::More tests => 27;

use Time::Clock;

my $t = Time::Clock->new;

ok($t->parse('12:34:56.123456789'), 'parse 12:34:56.123456789');
is($t->as_string, '12:34:56.123456789', 'check 12:34:56.123456789');

ok($t->parse('12:34:56.123456789 pm'), 'parse 12:34:56.123456789 pm');
is($t->as_string, '12:34:56.123456789', 'check 12:34:56.123456789 pm');

ok($t->parse('12:34:56. A.m.'), 'parse 12:34:56. A.m.');
is($t->as_string, '00:34:56', 'check 12:34:56 am');

ok($t->parse('12:34:56 pm'), 'parse 12:34:56 pm');
is($t->as_string, '12:34:56', 'check 12:34:56 pm');

ok($t->parse('2:34:56 pm'), 'parse 2:34:56 pm');
is($t->as_string, '14:34:56', 'check 14:34:56 pm');

ok($t->parse('2:34 pm'), 'parse 2:34 pm');
is($t->as_string, '14:34:00', 'check 2:34 pm');

ok($t->parse('2 pm'), 'parse 2 pm');
is($t->as_string, '14:00:00', 'check 2 pm');

ok($t->parse('3pm'), 'parse 3pm');
is($t->as_string, '15:00:00', 'check 3pm');

ok($t->parse('4 p.M.'), 'parse 4 p.M.');
is($t->as_string, '16:00:00', 'check 4 p.M.');

ok($t->parse('24:00:00'), 'parse 24:00:00');
is($t->as_string, '24:00:00', 'check 24:00:00');

ok($t->parse('24:00:00 PM'), 'parse 24:00:00 PM');
is($t->as_string, '24:00:00', 'check 24:00:00 PM');

ok($t->parse('24:00'), 'parse 24:00');
is($t->as_string, '24:00:00', 'check 24:00');

eval { $t->parse('24:00:00.000000001') };
ok($@ =~ /only allowed if/,  'parse fail 24:00:00.000000001');

eval { $t->parse('24:00:01') };
ok($@ =~ /only allowed if/,  'parse fail 24:00:01');

eval { $t->parse('24:01') };
ok($@ =~ /only allowed if/,  'parse fail 24:01');
