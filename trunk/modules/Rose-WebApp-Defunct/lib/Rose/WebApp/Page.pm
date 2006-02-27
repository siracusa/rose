package Rose::WebApp::Page;

use strict;

use Rose::WebApp::Comp;
our @ISA = qw(Rose::WebApp::Comp);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  array =>
  [
    'form_names'     => { interface => 'get_set' },
    'add_form_names' => { interface => 'add', hash_key => 'form_names' },
  ],
);

sub uri
{
  my($self) = shift;

  $self->{'uri'} = shift  if(@_);

  unless(defined $self->{'uri'})
  {
    return $self->{'uri'} = $self->init_uri;
  }

  my $app = $self->app || return $self->{'uri'};
  return $app->absolute_uri($self->{'uri'});
}

sub init_uri { sub { $_[0]->app->path_to_uri($_[0]->path) } }

1;
