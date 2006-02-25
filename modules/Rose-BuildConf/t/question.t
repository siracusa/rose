#!/usr/bin/perl -w

use strict;

use Test::More tests => 10;

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

my $question = 
  Rose::BuildConf::Question->new(
    class       => Rose::BuildConf::Class->new(class => 'My::Class'),
    question    => 'qu',
    conf_param  => 'B',
    prompt      => '>',
    default     => 'def',
    validate    => sub { 1 },
    pre_action  => sub { 1 },
    post_action => sub { 1 },
    post_set_action => sub { 1 },
    input_filter    => sub { my($s, %a) = @_; ucfirst $a{'value'} },
    output_filter   => sub { my($s, %a) = @_; uc $a{'value'} },
    error           => 0,
    skip_if         => sub { $My::Skip == 5 });

ok(UNIVERSAL::isa($question, 'Rose::BuildConf::Question'), 'new');

is($question->class_name, 'My::Class', 'class_name');

is($question->local_conf_value, undef, 'local_conf_value');

ok($question->conf_param_exists, 'conf_param_exists');

is($question->conf_value, 2, 'conf_value');

ok(!$question->should_skip, 'should_skip 1');

$My::Skip = 5;

ok($question->should_skip, 'should_skip 2');
