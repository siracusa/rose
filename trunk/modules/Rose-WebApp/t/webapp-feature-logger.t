#!/usr/bin/perl -w

use strict;

use Apache::Test qw(:withtestmore);
use Apache::TestRequest 'GET_BODY';
use Test::More;

plan tests => 1;

chomp(my $data = GET_BODY '/rose/webapp/features/logger');

is($data, 'Hello world', '/');
