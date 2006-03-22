#!/usr/bin/perl -w

use strict;

use Test::More 'no_plan'; #tests => 15;

BEGIN
{
  use_ok('Rose::HTML::Object');
  # Base classes?
  #use_ok('Rose::HTML::Object::Attachment::URI');
  #use_ok('Rose::HTML::Object::Attachment::Text');
  use_ok('Rose::HTML::Object::Attachment::JavaScript');
  #Rose::HTML::Object::Attachment::JavaScript::URI
  #Rose::HTML::Object::Attachment::JavaScript::Text
  use_ok('Rose::HTML::Object::Attachment::CSS');
  #Rose::HTML::Object::Attachment::CSS::URI
  #Rose::HTML::Object::Attachment::CSS::Text
}

my $o = Rose::HTML::Object->new;

$o->attach(name => 'js', uri  => '/foo/bar.js');
$o->attach(name => 'js', uri  => '/bar/baz.js');

is_deeply([ map { "$_" } $o->attachments('js') ], 
          [ '/foo/bar.js', '/bar/baz.js' ],
          'attach 1');

$o->attach(name => 'js', uri  => '/blee.js', position => 'first');

is_deeply([ map { "$_" } $o->attachments('js') ], 
          [ '/blee.js', '/foo/bar.js', '/bar/baz.js' ],
          'attach 2');

$o->attach(name => 'js', uri  => '/blah.js', position => 'last');

is_deeply([ map { "$_" } $o->attachments('js') ], 
          [ '/blee.js', '/foo/bar.js', '/bar/baz.js', '/blah.js' ],
          'attach 3');

$o->attach(name => 'js', uri  => '/middle.js', after => '/bar/baz.js');

is_deeply([ map { "$_" } $o->attachments('js') ], 
          [ '/blee.js', '/foo/bar.js', '/bar/baz.js', '/middle.js', '/blah.js' ],
          'attach 4');

$o->attach(name => 'js', uri  => '/m2.js', before => '/bar/baz.js');

is_deeply([ map { "$_" } $o->attachments('js') ], 
          [ '/blee.js', '/foo/bar.js', '/m2.js', '/bar/baz.js', '/middle.js', '/blah.js' ],
          'attach 5');

ok(ref $o->delete_attachment(name => 'js', uri => '/foo/bar.js') eq 
   'Rose::HTML::Object::Attachment::JavaScript', 'delete_attachment 1');
   
ok(!defined $o->delete_attachment(name => 'js', uri => 'nonesuch'), 'delete_attachment 2');

$o->delete_attachments('js');

is_deeply([ $o->attachments('js') ], [ ], 'delete_attachments 1');

$o->attach(name => 'js', uri => 'foo.js');

is_deeply([ map { $_->id } $o->attachments('js') ], [ 'foo.js' ], 'delete_attachments 1');

# Attach same thing twice
$o->attach(name => 'js', Rose::HTML::Object::Attachment::JavaScript->new(uri => 'bar.js'));
$o->attach(name => 'js', uri => 'bar.js');

is_deeply([ map { $_->id } $o->attachments('js') ], [ 'foo.js', 'bar.js' ], 'attach 6');

#
# JavaScript attachments
#

# URI

my $js = Rose::HTML::Object::Attachment::JavaScript->new(uri => '/blee.js');

is($js->uri, '/blee.js', 'js uri');
is($js->mime_type, 'text/javascript', 'js mime type');

is($js->html, '<script src="/blee.js" type="text/javascript"></script>', 'js uri html 1');
is($js->xhtml, '<script src="/blee.js" type="text/javascript" />', 'js uri html 1');

is($js->html_script, '<script src="/blee.js" type="text/javascript"></script>', 'js uri html script 1');
is($js->xhtml_script, '<script src="/blee.js" type="text/javascript" />', 'js uri html script 1');

my $s = $js->html_object;
is($s, 'Rose::HTML::Script', 'html_object');

$s = $js->xhtml_object;
is($s, 'Rose::HTML::Script', 'xhtml_object');

is($s->html, '<script src="/blee.js" type="text/javascript"></script>', 'js uri html 2');
is($s->xhtml, '<script src="/blee.js" type="text/javascript" />', 'js uri html 2');

# Script

$js = Rose::HTML::Object::Attachment::JavaScript->new(script => 'function foo() { return 123; }');

is($js->script, 'function foo() { return 123; }', 'js script');
is($js->text, 'function foo() { return 123; }', 'js text');

is($js->html, <<'EOF', 'js script html');
<script type="text/javascript">
<!--
function foo() { return 123; }
// -->
</script>
EOF

is($js->xhtml, <<'EOF', 'js script html');
<script type="text/javascript"><!--//--><![CDATA[//><!--
function foo() { return 123; }
//--><!]]></script>
EOF

#
# CSS attachments
#

#<link rel="stylesheet" type="text/css" href="/styles/coupon_admin.css" />
#is($js->html_link, '<link type="text/javascript"

# http://hixie.ch/advocacy/xhtml
#
#<style type="text/css"><!--/*--><![CDATA[/*><!--*/
#        ...
#/*]]>*/--></style>
