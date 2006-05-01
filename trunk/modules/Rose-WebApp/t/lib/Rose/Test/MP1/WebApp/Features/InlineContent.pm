package Rose::Test::MP1::WebApp::Features::InlineContent;

use strict;

use Rose::Test::MP1::MyApp;
our @ISA = qw(Rose::Test::MP1::MyApp);

__PACKAGE__->use_features('inline-content');

sub init_default_action { 'default' }

sub do_default
{
  my($self) = shift;
  $self->show_comp(path => '/foo/bar.html');
}

1;

__DATA__
---
Path:  /foo/bar.html
Lines: 1

Hello world
