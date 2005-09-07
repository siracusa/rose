#!/usr/bin/perl -w

use strict;

use Test::More tests => 18;

BEGIN
{
  use_ok('Rose::Conf::FileBased');
  use_ok('Rose::BuildConf::Class');
  use_ok('Rose::BuildConf::Question');
}

$My::Skip = 0;

@My::Class::ISA = qw(Rose::Conf::FileBased);

%My::Class::CONF = (); # -w grrrr....
%My::Class::CONF =
(
  A => 1,
  B => 2,
);

my $class = 
  Rose::BuildConf::Class->new(
    name     => 'My::Class',
    preamble => 'pa',
    skip_if  => sub { $My::Skip == 5 },
    questions => 
    [
      Rose::BuildConf::Question->new, 
      Rose::BuildConf::Question->new,
    ]);

ok(UNIVERSAL::isa($class, 'Rose::BuildConf::Class'), 'new');

is($class->name, 'My::Class', 'name');
is($class->class, 'My::Class', 'class');

is($class->preamble, 'pa', 'name');

is($class->num_questions, 2, 'num_questions 1');

$class->add_question(Rose::BuildConf::Question->new);

is($class->num_questions, 3, 'num_questions 2');

ok($class->conf_param_exists('A'), 'conf_param_exists 1');

ok(!$class->conf_param_exists('Z'), 'conf_param_exists 2');

is($class->conf_value('B'), 2, 'conf_value 1');

my $hash = $class->conf_hash;

is($hash, \%My::Class::CONF, 'conf_hash');

ok(!defined $class->local_conf_value('A'), 'local_conf_value');

my @questions = $class->questions;

ok(@questions == 3, 'questions 1');

my $questions = $class->questions;

ok(@$questions == 3, 'questions 2');

ok(!$class->should_skip, 'should_skip 1');

$My::Skip = 5;

ok($class->should_skip, 'should_skip 2');
