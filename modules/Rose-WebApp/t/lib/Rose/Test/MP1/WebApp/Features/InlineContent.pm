package Rose::Test::MP1::WebApp::Features::InlineContent;

use strict;

use Rose::Test::MP1::MyApp;
our @ISA = qw(Rose::Test::MP1::MyApp);

__PACKAGE__->use_features('inline-content');

sub init
{
  my($self) = shift;
  
  $self->uri_dispatch(
  {
    '/virtual' => 'virtual',
    '/real'    => 'real',
  });
}

sub do_virtual
{
  my($self) = shift;
  $self->show_comp(path => '/inline/hello.html');
}

sub do_real
{
  my($self) = shift;
  $self->show_comp(path => '/rose/webapp/features/inlinecontent/hello.html');
}

1;

__DATA__
---
Path:  /inline/hello.html
Lines: 1
Chomp: 1

Hello <& '/inline/world.mc', punct => '!' &>
---
Path:  /inline/world.mc
Lines: 1
Chomp: 1

world<% $ARGS{'punct'} || '?' %>
