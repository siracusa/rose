#!/usr/bin/perl -w

use strict;

use Test::More tests => 14;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::HTML::Form::Field::Compound');
}

my $field = Rose::HTML::Form::Field::Compound->new(name => 'date');
ok(ref $field && $field->isa('Rose::HTML::Form::Field::Compound'), 'new()');

my %fields =
(
  month => Rose::HTML::Form::Field::Text->new(
             name => 'month', 
             size => 2),

  day   => Rose::HTML::Form::Field::Text->new(
             name => 'day', 
             size => 2),

  year  => Rose::HTML::Form::Field::Text->new(
             name => 'year', 
             size => 4),
);

ok($field->add_fields(%fields), 'add_fields()');

is($field->field('month'), $fields{'month'}, 'field() set with field hash');

is($field->field('date.month'), $fields{'month'}, 'field() addressing');

$field->init_fields(month => 12, day => 25, year => 1980);

is(join("\n", map { $_->html_field } $field->fields),
   qq(<input name="date.day" size="2" type="text" value="25">\n) .
   qq(<input name="date.month" size="2" type="text" value="12">\n) .
   qq(<input name="date.year" size="4" type="text" value="1980">), 'html test');

is($field->html_hidden_fields,
   qq(<input name="date.day" type="hidden" value="25">\n) .
   qq(<input name="date.month" type="hidden" value="12">\n) .
   qq(<input name="date.year" type="hidden" value="1980">),
   'html_hidden_fields()');

is($field->xhtml_hidden_fields,
   qq(<input name="date.day" type="hidden" value="25" />\n) .
   qq(<input name="date.month" type="hidden" value="12" />\n) .
   qq(<input name="date.year" type="hidden" value="1980" />),
   'mdy xhtml_hidden_fields()');

is($field->html_hidden_field,
   qq(<input name="date.day" type="hidden" value="25">\n) .
   qq(<input name="date.month" type="hidden" value="12">\n) .
   qq(<input name="date.year" type="hidden" value="1980">),
   'html_hidden_field() 1');

is($field->xhtml_hidden_field,
   qq(<input name="date.day" type="hidden" value="25" />\n) .
   qq(<input name="date.month" type="hidden" value="12" />\n) .
   qq(<input name="date.year" type="hidden" value="1980" />),
   'mdy xhtml_hidden_field() 1');

{
  no warnings;
  *Rose::HTML::Form::Field::Compound::output_value = sub { '12/25/1980' };
}

is($field->html_hidden_field,
   qq(<input name="date" type="hidden" value="12/25/1980">),
   'html_hidden_field() 2');

is($field->xhtml_hidden_field,
   qq(<input name="date" type="hidden" value="12/25/1980" />),
   'xhtml_hidden_field() 2');

$field->clear();

is(join("\n", map { $_->html_field } $field->fields),
   qq(<input name="date.day" size="2" type="text" value="">\n) .
   qq(<input name="date.month" size="2" type="text" value="">\n) .
   qq(<input name="date.year" size="4" type="text" value="">), 'clear()');
