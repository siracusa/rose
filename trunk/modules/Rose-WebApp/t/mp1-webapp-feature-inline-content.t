#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Test::More;

plan tests => 2;

chomp(my $data = GET_BODY '/rose/webapp/features/inlinecontent/virtual');
is($data, 'Hello world!', '/rose/webapp/features/inlinecontent/virtual');

chomp($data = GET_BODY '/rose/webapp/features/inlinecontent/real');
is($data, 'Hello world!', '/rose/webapp/features/inlinecontent/real');
