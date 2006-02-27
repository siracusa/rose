package Rose::WebApp::Dispatch::Apache1;

use strict;

use Apache::Constants qw(OK REDIRECT);

use Rose::WebApp::Server::Module;
our @ISA = qw(Rose::WebApp::Server::Module);

our %Apps;

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(  
  'scalar --get_set_init' => [ 'app' ],
  scalar => 'apr',
);

sub get_app
{
  my($class, $app_class) = @_;
  return return $Apps{$app_class} ||= $app_class->new();
}

sub init_app
{
  my($self) = shift;

  my $r = $self->apache->request;

  my $class = $r->dir_config('RoseWebAppClass')
    or die "No RoseWebAppClass defined for this location (URI = ",  $r->uri, ")";

  if($r->dir_config('RoseWebAppNoCache'))
  {
    return $class->new;
  }
  else
  {
    return $Apps{$class} ||= $class->new;
  }
}

sub handler($$)
{
  my($self, $r) = @_;

  $r->content_type('text/html');

  $self = $self->new($r)  unless(ref $self);

  $self->sanity_check() or return $self->status;
  my $app = $self->app;
  $app->apache->request($r);
  $self->parse_query($r, $app) or return $self->status;

  return $self->handle_request($r, $app);
}

sub handle_request
{
  my($self, $r, $app) = @_;

  $app ||= $self->app;

  $r->register_cleanup(sub { $app->refresh() });

  $app->params($self->params);

  # Support Apache::Filter hooks
  #if(lc $r->dir_config('Filter') eq 'on')
  #{
  #  $r->filter_register;
  #  $app->http_header_sent(1);  
  #}

  $app->run();

  return $app->status;
}

1;
