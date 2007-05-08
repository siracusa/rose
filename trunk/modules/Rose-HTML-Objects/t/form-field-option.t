#!/usr/bin/perl -w

use strict;

use Test::More tests => 18;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::Option');
}

my $field = Rose::HTML::Form::Field::Option->new(
  value => 'john',
  label => 'John');

ok(ref $field eq 'Rose::HTML::Form::Field::Option', 'new()');

is($field->html_field, '<option value="john">John</option>', 'html_field() 1');
is($field->xhtml_field, '<option value="john">John</option>', 'xhtml_field() 1');

$field->class('foo');
$field->id('bar');
$field->style('baz');

is($field->html_field, '<option class="foo" id="bar" style="baz" value="john">John</option>', 'html_field() 2');
is($field->xhtml_field, '<option class="foo" id="bar" style="baz" value="john">John</option>', 'xhtml_field() 2');

$field->default(1);

is($field->html_field, '<option class="foo" id="bar" selected style="baz" value="john">John</option>', 'html_field() 3');
is($field->xhtml_field, '<option class="foo" id="bar" selected="selected" style="baz" value="john">John</option>', 'xhtml_field() 3');
$DB::single = 1;
is($field->html_tag, '<option class="foo" id="bar" selected style="baz" value="john">John</option>', 'html_tag() 1');
is($field->xhtml_tag, '<option class="foo" id="bar" selected="selected" style="baz" value="john">John</option>', 'xhtml_tag() 1');

is($field->selected, 1, 'selected() 1');
is($field->is_selected, 1, 'is_selected() 1');

$field->clear;

is($field->html_field, '<option class="foo" id="bar" style="baz" value="john">John</option>', 'html_field() 4');
is($field->xhtml_field, '<option class="foo" id="bar" style="baz" value="john">John</option>', 'xhtml_field() 4');

$field->delete_html_attrs(qw(class style id));

$field->short_label('1.0');

is($field->html_field, '<option label="1.0" value="john">John</option>', 'html_field() 5');
is($field->xhtml_field, '<option label="1.0" value="john">John</option>', 'xhtml_field() 5');

$field->selected(1);

is($field->html_field, '<option label="1.0" selected value="john">John</option>', 'html_field() 6');
is($field->xhtml_field, '<option label="1.0" selected="selected" value="john">John</option>', 'xhtml_field() 6');
