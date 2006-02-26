#!/usr/bin/perl -w

use strict;

use Test::More tests => 27;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::Object');
}

my $field = Rose::HTML::Form::Field::Text->new(
  label       => 'Name', 
  description => 'Your name',
  name        => 'name',  
  value       => 'John',
  default     => 'Anonymous',
  maxlength   => 20);

ok(ref $field eq 'Rose::HTML::Form::Field::Text', 'new()');

is($field->html_field, '<input maxlength="20" name="name" size="15" type="text" value="John">', 'html_field() 1');
is($field->xhtml_field, '<input maxlength="20" name="name" size="15" type="text" value="John" />', 'xhtml_field() 1');

$field->clear;

is($field->internal_value, undef, 'clear()');

is($field->html_field, '<input maxlength="20" name="name" size="15" type="text" value="">', 'html_field() 2');
is($field->xhtml_field, '<input maxlength="20" name="name" size="15" type="text" value="" />', 'xhtml_field() 2');

$field->reset;

is($field->input_value, 'Anonymous', 'reset() 1');
is($field->internal_value, 'Anonymous', 'reset() 2');
is($field->output_value, 'Anonymous', 'reset() 3');

is($field->html_field, '<input maxlength="20" name="name" size="15" type="text" value="Anonymous">', 'html_field() 3');
is($field->xhtml_field, '<input maxlength="20" name="name" size="15" type="text" value="Anonymous" />', 'xhtml_field() 3');

$field->input_value('John');

$field->class('foo');
$field->id('bar');
$field->style('baz');

is($field->html_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="John">', 'html_field() 4');
is($field->xhtml_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="John" />', 'xhtml_field() 4');

$field->input_filter(sub
{
  my($self, $value) = @_;

  if($value =~ /\S/)
  {
    return Person->new(name => $value);
  }

  return $value;
});

$field->input_value('John2');

my $p = $field->internal_value;

is(ref $p, 'Person', 'internal_value() 2');
is($p->name, 'John2', 'internal_value() 3');

$field->output_filter(sub
{
  my($self, $value) = @_;

  return $value->name  if(ref $value eq 'Person');
  return $value;
});

is($field->output_value, 'John2', 'output_value() 1');

is($field->html_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="John2">', 'html_field() 5');
is($field->xhtml_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="John2" />', 'xhtml_field() 5');

$field->reset;

$field->default_value('Anonymous');

is($field->input_value, 'Anonymous', 'reset() 1');
is($field->internal_value->name, 'Anonymous', 'reset() 2');
is($field->output_value, 'Anonymous', 'reset() 3');

is($field->html_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="Anonymous">', 'html_field() 6');
is($field->xhtml_field, '<input class="foo" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="Anonymous" />', 'xhtml_field() 6');

$field->html_attr(disabled => 1);

is($field->html_field, '<input class="foo" disabled id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="Anonymous">', 'html_field() 7');
is($field->xhtml_field, '<input class="foo" disabled="disabled" id="bar" maxlength="20" name="name" size="15" style="baz" type="text" value="Anonymous" />', 'xhtml_field() 7');

BEGIN
{
  package Person;

  use strict;

  @Person::ISA = qw(Rose::Object);

  use Rose::Object::MakeMethods::Generic
  (
    'scalar' => [ qw(name age) ],
  );
}
