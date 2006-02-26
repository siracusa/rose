#!/usr/bin/perl -w

use strict;

use Test::More tests => 10;

BEGIN { use_ok('Rose::HTML::Object::WithContents') }

my $o = Rose::HTML::Object::WithContents->new;
ok(ref $o eq 'Rose::HTML::Object::WithContents', 'new()');

is(Rose::HTML::Object::WithContents->html_element('foo'), 'foo', 'html_element()');
is(Rose::HTML::Object::WithContents->xhtml_element('xfoo'), 'xfoo', 'xhtml_element()');

is($o->html_tag, '<foo></foo>', 'html_tag() 1');
is($o->xhtml_tag, '<xfoo></xfoo>', 'xhtml_tag() 1');

is($o->html_tag(contents => '<b>bar</b>'), '<foo><b>bar</b></foo>', 'html_tag() 2');
is($o->xhtml_tag(contents => '<b>bar</b>'), '<xfoo><b>bar</b></xfoo>', 'xhtml_tag() 2');

$o->contents('baz');

is($o->html_tag, '<foo>baz</foo>', 'html_tag() 3');
is($o->xhtml_tag, '<xfoo>baz</xfoo>', 'xhtml_tag() 3');
