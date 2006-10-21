#!/usr/local/bin/perl -w

use strict;

use Rose::HTML::Object::Errors qw(:number);

BEGIN
{
  use Test::More tests => 32;
  use_ok('Rose::HTML::Form::Field::Integer');
}

my $field = Rose::HTML::Form::Field::Integer->new(
  label       => 'Num', 
  description => 'Your num',
  name        => 'num',  
  value       => 123,
  default     => 456,
  maxlength   => 7);

ok(ref $field eq 'Rose::HTML::Form::Field::Integer', 'new()');

is($field->html_field, '<input maxlength="7" name="num" size="6" type="text" value="123">', 'html_field() 1');
is($field->xhtml_field, '<input maxlength="7" name="num" size="6" type="text" value="123" />', 'xhtml_field() 1');

$field->clear;

is($field->internal_value, undef, 'clear()');

is($field->html_field, '<input maxlength="7" name="num" size="6" type="text" value="">', 'html_field() 2');
is($field->xhtml_field, '<input maxlength="7" name="num" size="6" type="text" value="" />', 'xhtml_field() 2');

$field->reset;

is($field->internal_value, '456', 'reset()');

is($field->html_field, '<input maxlength="7" name="num" size="6" type="text" value="456">', 'html_field() 3');
is($field->xhtml_field, '<input maxlength="7" name="num" size="6" type="text" value="456" />', 'xhtml_field() 3');

$field->input_value('123');

$field->class('foo');
$field->id('bar');
$field->style('baz');

is($field->html_field, '<input class="foo" id="bar" maxlength="7" name="num" size="6" style="baz" type="text" value="123">', 'html_field() 4');
is($field->xhtml_field, '<input class="foo" id="bar" maxlength="7" name="num" size="6" style="baz" type="text" value="123" />', 'xhtml_field() 4');

$field->input_value('bad');  
ok(!$field->validate, 'validate() 1');
is($field->error, 'Num must be an integer.', 'error() 1');
is($field->error_id, NUM_INVALID_INTEGER, 'error_id() 1');

$field->input_value('7^7');  
ok(!$field->validate, 'validate() 2');

$field->input_value('1.23');  
ok(!$field->validate, 'validate() 3');

$field->input_value(' 123 ');  
ok($field->validate, 'validate() 4');

ok(!$field->error, 'error() 2');

$field->input_value(-5);
ok($field->validate, 'validate() 5');
ok(!$field->error, 'error() 3');

$field->min(0);
ok(!$field->validate, 'validate() 6');
is($field->error, 'Num must be a positive integer.', 'error() 4');
is($field->error_id, NUM_NOT_POSITIVE_INTEGER, 'error_id() 2');

$field->min(1);
ok(!$field->validate, 'validate() 7');
is($field->error, 'Num must be greater than 0.', 'error() 4');
is($field->error_id, NUM_BELOW_MIN, 'error_id() 3');

$field->max(100);
$field->input_value(100);

ok($field->validate, 'validate() 8');
ok(!$field->has_error, 'error() 4');

$field->input_value(101);
ok(!$field->validate, 'validate() 9');
is($field->error, 'Num must be less than or equal to 100.', 'error() 4');
is($field->error_id, NUM_ABOVE_MAX, 'error_id() 4');