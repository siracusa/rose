#!/usr/local/bin/perl -w

use strict;

use Test::More tests => 35;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::Option');
  use_ok('Rose::HTML::Form::Field::PopUpMenu');
}

my $field = Rose::HTML::Form::Field::PopUpMenu->new(name => 'fruits');

ok(ref $field eq 'Rose::HTML::Form::Field::PopUpMenu', 'new()');

is(scalar @{ $field->children }, 0, 'children scalar 1');
is(scalar(() = $field->children), 0, 'children list 1');

$field->options(apple  => 'Apple',
                orange => 'Orange',
                grape  => 'Grape');

is(scalar @{ $field->children }, 3, 'children scalar 2');
is(scalar(() = $field->children), 3, 'children list 2');

is(join(',', sort $field->labels), 'Apple,Grape,Orange,apple,grape,orange', 'labels()');

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select>),
  'html_field() 1');

is($field->value_label('apple'), 'Apple', 'label()');

$field->option('apple')->label('<b>Apple</b>');
$field->escape_html(0);

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">&lt;b&gt;Apple&lt;/b&gt;</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select>),
  'escape_html() 1');

$field->escape_html(1);

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">&lt;b&gt;Apple&lt;/b&gt;</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select>),
  'escape_html() 1');

$field->option('apple')->label('Apple');

$field->default('apple');

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option selected value="apple">Apple</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select>),
  'default()');

$field->value('orange');

is(($field->input_value)[0], 'orange', 'input_value()');
is(($field->internal_value)[0], 'orange', 'internal_value()');
is(($field->output_value)[0], 'orange', 'output_value()');

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option selected value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select>),
  'value() 1');

$field->error("Do not pick orange!");

is($field->html, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option selected value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select><br>\n) .
  qq(<span class="error">Do not pick orange!</span>),
  'html()');

is($field->xhtml, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option selected="selected" value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(</select><br />\n) .
  qq(<span class="error">Do not pick orange!</span>),
  'html()');

$field->error(undef);

ok($field->is_selected('orange'), 'is_selected() 1');
ok(!$field->is_selected('apple'), 'is_selected() 2');
ok(!$field->is_selected('foo'), 'is_selected() 3');

ok($field->has_value('orange'), 'has_value() 1');
ok(!$field->has_value('apple'), 'has_value() 2');
ok(!$field->has_value('foo'), 'has_value() 3');

$field->add_options(pear => 'Pear', berry => 'Berry');

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option selected value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(<option value="pear">Pear</option>\n) .
  qq(<option value="berry">Berry</option>\n) .
  qq(</select>),
  'add_options() hash');

$field->add_options(Rose::HTML::Form::Field::Option->new(value => 'squash', label => 'Squash'),
                    Rose::HTML::Form::Field::Option->new(value => 'cherry', label => 'Cherry'));

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option selected value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(<option value="pear">Pear</option>\n) .
  qq(<option value="berry">Berry</option>\n) .
  qq(<option value="squash">Squash</option>\n) .
  qq(<option value="cherry">Cherry</option>\n) .
  qq(</select>),
  'add_options() objects');

is($field->html_hidden_field, 
  qq(<input name="fruits" type="hidden" value="orange">),
  'html_hidden_field()');

is($field->html_hidden_fields, 
  qq(<input name="fruits" type="hidden" value="orange">),
  'html_hidden_fields()');

is(join("\n", map { $_->html } $field->hidden_field),
  qq(<input name="fruits" type="hidden" value="orange">),
  'hidden_field()');

is(join("\n", map { $_->html } $field->hidden_fields),
  qq(<input name="fruits" type="hidden" value="orange">),
  'hidden_fields()');

$field->clear;

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option value="apple">Apple</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(<option value="pear">Pear</option>\n) .
  qq(<option value="berry">Berry</option>\n) .
  qq(<option value="squash">Squash</option>\n) .
  qq(<option value="cherry">Cherry</option>\n) .
  qq(</select>),
  'clear()');

$field->reset;

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option selected value="apple">Apple</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(<option value="pear">Pear</option>\n) .
  qq(<option value="berry">Berry</option>\n) .
  qq(<option value="squash">Squash</option>\n) .
  qq(<option value="cherry">Cherry</option>\n) .
  qq(</select>),
  'reset()');

$field->input_value('apple');

is($field->html_field, 
  qq(<select name="fruits" size="1">\n) .
  qq(<option selected value="apple">Apple</option>\n) .
  qq(<option value="orange">Orange</option>\n) .
  qq(<option value="grape">Grape</option>\n) .
  qq(<option value="pear">Pear</option>\n) .
  qq(<option value="berry">Berry</option>\n) .
  qq(<option value="squash">Squash</option>\n) .
  qq(<option value="cherry">Cherry</option>\n) .
  qq(</select>),
  'input_value() 2');

eval { $field->input_value([ 'apple', 'cherry' ]) };

ok($@, 'multiple values');
