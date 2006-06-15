#!/usr/bin/perl -w

use strict;

use Test::More tests => 23;

use Time::Clock;

my $t = Time::Clock->new;

$t->parse('12:34:56.123456789');
is($t->format('%H %I %i %M %S %N %n %p'), '12 12 12 34 56 123456789 .123456789 PM', 'format %H %I %i %M %S %N %p 1');

$t->parse('13:34:56.123');
is($t->format('%H %I %i %M %S %N %n %p'), '13 01 1 34 56 123000000 .123000000 PM', 'format %H %I %i %M %S %N %p 2');

$t->parse('1:23:45');
is($t->format('%n'), '', 'format %n 1');

$t->nanosecond(0);
is($t->format('%n'), '.000000000', 'format %n 2');

$t->nanosecond(123456789);
is($t->format('%1N'), 1, 'format %1N');
is($t->format('%2N'), 12, 'format %2N');
is($t->format('%3N'), 123, 'format %3N');
is($t->format('%4N'), 1234, 'format %4N');
is($t->format('%5N'), 12345, 'format %5N');
is($t->format('%6N'), 123456, 'format %6N');
is($t->format('%7N'), 1234567, 'format %7N');
is($t->format('%8N'), 12345678, 'format %8N');
is($t->format('%9N'), 123456789, 'format %9N');

is($t->format('%1n'), '.1', 'format %1n');
is($t->format('%2n'), '.12', 'format %2n');
is($t->format('%3n'), '.123', 'format %3n');
is($t->format('%4n'), '.1234', 'format %4n');
is($t->format('%5n'), '.12345', 'format %5n');
is($t->format('%6n'), '.123456', 'format %6n');
is($t->format('%7n'), '.1234567', 'format %7n');
is($t->format('%8n'), '.12345678', 'format %8n');
is($t->format('%9n'), '.123456789', 'format %9n');

$t->parse('12:34:56.123456789');

$t->format('%H%%%M%%%2N');
is($t->format('%H%%%M%%%2N'), '12%34%12', 'format %H%%%M%%%2N');
