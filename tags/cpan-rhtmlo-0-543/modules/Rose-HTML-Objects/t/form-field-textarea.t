#!/usr/bin/perl -w

use strict;

use Test::More tests => 18;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::TextArea');
}

my $field = Rose::HTML::Form::Field::TextArea->new(
  name    => 'name',  
  value   => 'John & Tina',
  default => 'Anonymous');

ok(ref $field eq 'Rose::HTML::Form::Field::TextArea', 'new()');

is($field->html_field, 
   '<textarea cols="50" name="name" rows="6">John &amp; Tina</textarea>',
   'html_field() 1');

is($field->xhtml_field,
   '<textarea cols="50" name="name" rows="6">John &amp; Tina</textarea>',
   'xhtml_field() 1');

$field->input_value(' John & Tina ');

is($field->html_field,
   '<textarea cols="50" name="name" rows="6">John &amp; Tina</textarea>',
   'html_field() 2');

is($field->xhtml_field,
   '<textarea cols="50" name="name" rows="6">John &amp; Tina</textarea>',
   'xhtml_field() 2');

$field->clear;

is($field->html_field, 
   '<textarea cols="50" name="name" rows="6"></textarea>',
   'html_field() 3');

is($field->xhtml_field,
   '<textarea cols="50" name="name" rows="6"></textarea>',
   'xhtml_field() 3');

$field->reset;

is($field->html_field, 
   '<textarea cols="50" name="name" rows="6">Anonymous</textarea>',
   'html_field() 4');

is($field->xhtml_field,
   '<textarea cols="50" name="name" rows="6">Anonymous</textarea>',
   'xhtml_field() 4');

$field->contents('John');

$field->class('foo');
$field->id('bar');
$field->style('baz');

$field->rows(10);
$field->cols(80);
$field->disabled('abc');

is($field->size, '80x10', 'size() 1');

is($field->html_field, 
   '<textarea class="foo" cols="80" disabled id="bar" name="name" rows="10" style="baz">John</textarea>',
   'html_field() 5');

is($field->xhtml_field,
   '<textarea class="foo" cols="80" disabled="disabled" id="bar" name="name" rows="10" style="baz">John</textarea>',
   'xhtml_field() 5');

is($field->size, '80x10', 'size() 1');

eval { $field->size(90) };
ok($@, 'invalid size');

is($field->size('50x3'), '50x3', 'size() 1');

is($field->html_field, 
   '<textarea class="foo" cols="50" disabled id="bar" name="name" rows="3" style="baz">John</textarea>',
   'html_field() 6');

is($field->xhtml_field,
   '<textarea class="foo" cols="50" disabled="disabled" id="bar" name="name" rows="3" style="baz">John</textarea>',
   'xhtml_field() 6');
