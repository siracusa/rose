#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

BEGIN 
{
  use_ok('Rose::HTML::Form::Field::Hidden');
}

my $field = Rose::HTML::Form::Field::Hidden->new(name  => 'name',  
                                                value => 'John');

ok(ref $field eq 'Rose::HTML::Form::Field::Hidden', 'new()');

is($field->html_field, '<input name="name" type="hidden" value="John">', 'html_field()');
is($field->xhtml_field, '<input name="name" type="hidden" value="John" />', 'xhtml_field()');
