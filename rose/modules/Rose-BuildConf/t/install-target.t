#!/usr/bin/perl -w

use strict;

use Test::More tests => 19;

use FindBin qw($Bin);

BEGIN
{
  use_ok('Rose::BuildConf::Install::Target');
}

$My::Skip = 0;

my $target = 
  Rose::BuildConf::Install::Target->new(
    name      => 'Foo',
    tag       => 'foo',
    preamble  => 'pa',
    source    => "$Bin/build",
    skip      => sub { $My::Skip == 5 },
    reinstall => 0,
    force     => 0);

ok(UNIVERSAL::isa($target, 'Rose::BuildConf::Install::Target'), 'new');

is($target->name, 'Foo', 'name');
is($target->tag, 'foo', 'tag');

is($target->preamble, 'pa', 'name');

is($target->source, "$Bin/build", 'num_questions 1');

is($target->enabled, 1, 'enabled 1');
is($target->is_enabled, 1, 'is_enabled 1');
is($target->is_disabled, 0, 'is_disabled 1');

$target->disable;

is($target->enabled, 0, 'enabled 2');
is($target->is_enabled, 0, 'is_enabled 2');
is($target->is_disabled, 1, 'is_disabled 2');

$target->enable;

is($target->enabled, 1, 'enabled 3');
is($target->is_enabled, 1, 'is_enabled 3');
is($target->is_disabled, 0, 'is_disabled 3');

is($target->recursive, 1, 'recursive');

is($target->mode, 'copy', 'mode');

ok(!$target->should_skip, 'should_skip 1');

$My::Skip = 5;

ok($target->should_skip, 'should_skip 2');
