#!/usr/bin/perl -w

use strict;

use Test::More tests => 9;

BEGIN 
{
  use_ok('Rose::HTML::Label');
}

my $label = Rose::HTML::Label->new(
  for       => 'foo',  
  accesskey => 't');

ok(ref $label eq 'Rose::HTML::Label', 'new()');

is($label->html_tag, '<label accesskey="t" for="foo"></label>', 'html_tag() 1');
is($label->xhtml_tag, '<label accesskey="t" for="foo"></label>', 'xhtml_tag() 1');

is($label->contents('blah'), 'blah', 'contents()');

is($label->html_tag, '<label accesskey="t" for="foo">blah</label>', 'html_tag() 2');
is($label->xhtml_tag, '<label accesskey="t" for="foo">blah</label>', 'xhtml_tag() 2');

is($label->html_tag(contents => '<b>hi</b>'), '<label accesskey="t" for="foo"><b>hi</b></label>', 'html_tag() 4');
is($label->xhtml_tag(contents => '<b>hi</b>'), '<label accesskey="t" for="foo"><b>hi</b></label>', 'xhtml_tag() 3');

