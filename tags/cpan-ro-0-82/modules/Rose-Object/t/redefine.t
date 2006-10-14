#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

use FindBin qw($Bin);
use lib "t/lib";

use Person1;
use Person2;

delete $INC{'Person1.pm'};
eval { require Person1 };
print $@  if($@);
ok(!$@, 'redefine 1');

delete $INC{'Person2.pm'};
eval { require Person2 };
print $@  if($@);
ok(!$@, 'redefine 2');

