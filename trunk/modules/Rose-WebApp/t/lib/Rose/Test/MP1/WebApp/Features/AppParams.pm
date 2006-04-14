package Rose::Test::MP1::WebApp::Features::AppParams;

use strict;

use Rose::Test::MP1::MyApp;
our @ISA = qw(Rose::Test::MP1::MyApp);

__PACKAGE__->use_features('app-params');

sub init_default_action { 'default' }

sub do_default
{
  my($self) = shift;
  $self->show_comp(path => $self->app_uri('app_params.html'));
}

1;
