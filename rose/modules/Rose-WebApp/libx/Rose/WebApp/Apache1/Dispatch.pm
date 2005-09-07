package Rose::WebSite::Apache::App;

use strict;

use Apache::Constants qw(OK REDIRECT);

use Rose::Apache::Module;
our @ISA = qw(Rose::Apache::Module);

our(%Apps, $Interp);

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(  
  'scalar --get_set_init' => [ 'app', 'mason_interp' ],
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

  my $r = $self->apache_request;

  my $class = $r->dir_config('RoseAppClass')
    or die "No RoseAppClass defined for this location (URI = ",  $r->uri, ")";

  if($r->dir_config('RoseNoAppCache'))
  {
    return $class->new(is_main => 1);
  }
  else
  {
    return $Apps{$class} ||= $class->new(is_main => 1);
  }
}

sub init_mason_interp { $Interp ||= Rose::WebSite->new_mason_interp }

sub handler($$)
{
  my($self, $r) = @_;

  $r->content_type('text/html; charset="ISO-8859-1"');

  $self = $self->new($r)  unless(ref $self);

  $self->sanity_check() or return $self->status;
  my $app = $self->app;
  $self->parse_query($r, $app)  or return $self->status;

  my $ret = $self->handle_request($r, $app);

  if($r->is_initial_req)
  {
    if(my $session = Rose::WebSite->session)
    {
      $session->store_if_modified;
    }

    Rose::Apache::Notes->clear();
  }

  return $ret;
}

sub handle_request
{
  my($self, $r, $app) = @_;

  $app ||= $self->app;

  $app->refresh();

  $app->params($self->params);
  $app->mason_interp($self->mason_interp);

  # Support Apache::Filter hooks
  if(lc $r->dir_config('Filter') eq 'on')
  {
    $r->filter_register;
    $app->http_header_sent(1);  
  }

  $app->run();

  my $status = $app->status;

  $app->clear();

  return $status;
}

sub parse_query
{
  my($self, $r, $app) = @_;

  my $apr = $app->init_apr($r);

  # Parse the form data, if any
  my $status = $apr->parse();

  # Puke if the submission has errors
  unless($status == OK)
  {
    $apr->custom_response($status, $apr->notes("error-notes"));
    $self->return($status);
    return;
  }

  # Import all the parameter symbols
  $self->_import_params($apr);

  return 1;
}

1;
