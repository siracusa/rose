#!/usr/bin/perl -w

use strict;

use Test::More tests => 16;

BEGIN
{
  use_ok('Rose::HTML::Anchor');
  use_ok('Rose::HTML::Image');
}

my $a = Rose::HTML::Anchor->new(href => 'apple.html', link => 'Apple');

is($a->link, 'Apple', 'link');
is($a->contents, 'Apple', 'contents');
is($a->href, 'apple.html', 'href');

is($a->html,'<a href="apple.html">Apple</a>', 'html 1');
is($a->xhtml, '<a href="apple.html">Apple</a>', 'xhtml 2');

$a->contents(Rose::HTML::Image->new(src => 'a.gif'));

is($a->html, '<a href="apple.html"><img alt="" src="a.gif"></a>', 'html 2');
is($a->xhtml, '<a href="apple.html"><img alt="" src="a.gif" /></a>', 'xhtml 2');

my $img = Rose::HTML::Image->new(src => 'b.gif');

$a->contents($img, 'foo');

is($a->html, '<a href="apple.html"><img alt="" src="b.gif">foo</a>', 'html 3');
is($a->xhtml, '<a href="apple.html"><img alt="" src="b.gif" />foo</a>', 'xhtml 3');

is($a->contents, $img, 'contents 2');

is($a->start_html, '<a href="apple.html">', 'start_html 1');
is($a->end_html, '</a>', 'end_html 1');

is($a->start_xhtml, '<a href="apple.html">', 'start_xhtml 1');
is($a->end_xhtml, '</a>', 'end_xhtml 1');
