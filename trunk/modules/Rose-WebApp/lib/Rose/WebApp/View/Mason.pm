package Rose::WebApp::View::Mason;

use strict;

use Carp;

use Scalar::Util();
use HTML::Mason::Interp;
use HTML::Mason::Request();

use Rose::WebApp::Server::Constants qw(OK NOT_FOUND SERVER_ERROR);

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    'path',
    'status',
    'output_ref',
    'error',
  ],

  'scalar --get_set_init' =>
  [
    'mason_interp',
    'mason_request',
  ],

  boolean => 'inlined_error',
);

sub init_mason_request { HTML::Mason::Request->instance }

sub init_mason_interp
{
  my($self) = shift;

  my $site = $self->app->website;

  if($site->can('mason_interp'))
  {
    return $site->mason_interp;
  }

  HTML::Mason::Interp->new(
    comp_root     => $self->app->server->request->document_root,
    allow_globals => [ qw($r $app) ]);
}

sub app
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'app'} = shift)  if(@_);
  return $self->{'app'};
}

sub reset
{
  my($self) = shift;

  $self->output_ref(undef);
  $self->error(undef);
  $self->status(undef);

  return 1;
}

sub output_comp
{
  my($self) = shift;

  my $app = $self->app or die "Missing application object";

  my $ret = $self->run_comp(@_);

  if(!$ret && $app->comp_error_mode eq 'inline')
  {
    $self->status(OK);

    if(my $m = $self->mason_request)
    {
      #$app->add_output($self->error);
      #$m->print($app->apache->escape_html($self->error));
      $m->print($self->error);
      $self->inlined_error(1);
    }
    else
    {
      $self->inlined_error(0);
    }
  }

#print STDERR "ADD TO APP OUTPUT: ", ${ $self->output_ref || \'' }, "\n";#'
  $app->add_output($self->output_ref);
#print STDERR "NEW TO APP OUTPUT: ", $app->output_buffer, "\n";

  $self->output_ref(undef);
  $app->status($self->status);
  $app->error($self->error);

  return $ret;
}

sub run_comp
{
  my($self, %args) = @_;

  my $path = $args{'path'} or croak "Missing path argument";
  my $args = $args{'args'} || [];
#print STDERR "RUN COMP $path\n";
  $self->error(undef);
  $self->status(undef);

  my($buffer, $m);

  if($m = $self->mason_request)
  {
#print STDERR "CHECK COMP WITH $m\n";
    unless($m->interp->comp_exists($path))
    {
#print STDERR "CHECK FAILED FOR $path\n";
      $self->error("Component does not exist: $path");
      $self->status(NOT_FOUND);
      return 0;
    }

    $m->interp->set_global('app' => $self->app);
#print STDERR "RUN $path $@args\n";
    eval { $m->comp($path, @$args) };
  }
  else
  {
    my $interp = $self->mason_interp;
#print STDERR "CHECK COMP WITH $interp\n";
    unless($interp->comp_exists($path))
    {
#print STDERR "INTERP CHECK FAILED FOR $path\n";
      $self->error("Component does not exist: $path");
      $self->status(NOT_FOUND);
      return 0;
    }

    $interp->out_method(\$buffer);
    $interp->set_global('app' => $self->app);
    $interp->set_global('site' => $self->app->website_class);
#print STDERR "RUN INTERP $path $@args\n";
    eval
    {
      $m = $interp->make_request(comp => $path, args => $args);
      #$m->error_mode(...);
      #$m->error_format(...);
      $self->mason_request($m);
      $m->exec;
    };

    $self->mason_request(undef);
  }

  # handle exception, which may be an HTML::Mason::Exception::Aborted object
  if(my $err = $@)
  {
#print STDERR "ERROR - $err\n";
    if(ref $err && $err->isa('HTML::Mason::Exception::Aborted'))
    {
      $self->error("Execution of component '$path' aborted! - $err");
      return undef;
    }
    else
    {
      $self->error("Execution of component '$path' failed! - $err");
      return undef;
    }

    #$self->status(SERVER_ERROR);
    #return undef;
  }

  $self->add_output(\$buffer);

  $self->status(OK);

  return 1;
}

sub add_output
{
  my($self) = shift;
#print STDERR "ADD OUTPUT: ${$_[0]}\n";
  my $output_ref = $self->output_ref;
  $$output_ref .= ${$_[0]};
  $self->output_ref($output_ref);
#print STDERR "NEW OUTPUT: $$output_ref\n";
}

sub output
{
  my($self) = shift;

  my $ref = $self->output_ref;

  return $ref ? $$ref : '';
}

1;
