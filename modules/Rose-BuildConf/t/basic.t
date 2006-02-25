#!/usr/bin/perl -w

use strict;

use Test::More tests => 3;

BEGIN
{
  use_ok('Rose::Conf');
  use_ok('Rose::Conf::FileBased');
  use_ok('Rose::BuildConf');
}
