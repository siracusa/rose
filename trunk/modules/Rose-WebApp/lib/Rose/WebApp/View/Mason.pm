package Rose::WebApp::View::Mason;

use strict;

use Carp;

use Scalar::Util();
use HTML::Mason::Interp;
use HTML::Mason::Request();
use use HTML::Mason::Resolver::Null();

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
    'mason_interp_inline',
    'mason_request',
  ],

  boolean => 'inlined_error',
);

# For processing inline content
our $Interp_Inline =

sub init_mason_request { HTML::Mason::Request->instance }

sub init_mason_interp
{
  my($self) = shift;

  my $site = $self->app->website;

  if($site->can('mason_interp'))
  {
    return $site->mason_interp;
  }

  my $doc_root = $self->app->server->request->document_root;
  my $comp_root = Path::Class::Dir->new($doc_root)->parent->subdir('comps');
  my $data_dir  = Path::Class::Dir->new($doc_root)->parent->subdir('mason/data');

  my %params = (allow_globals => [ qw($r $app) ]);
  
  if(-e $data_dir)
  {
    $params{'data_dir'} = $data_dir;
  }
  
  if(-e $comp_root)
  {
    $params{'comp_root'} =
    [
      docs  => $doc_root,
      comps => $comp_root,
    ];
  }
  else
  {
    $params{'comp_root'} = $doc_root;
  }

  return HTML::Mason::Interp->new(%params);
}

sub init_mason_interp_inline 
{
  my($self) = shift;

  my $interp = HTML::Mason::Interp->new(resolver_class => 'HTML::Mason::Resolver::Null');

  $interp->set_global('app' => $self->app);
  $interp->set_global('site' => $self->app->website_class);

  return $interp;
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

  if(my $comp_source = $self->inline_content(type => 'mason-comp',
                                             path => $path))
  {
    my $interp = $self->mason_interp_inline;
#print STDERR "INLINE COMP WITH $interp\n";
    $interp->set_global('app' => $self->app);

    my $comp = $interp->make_component(comp_source => $comp_source);
    my $request = $interp->make_request(out_method => \$buffer, comp => $comp);
    eval { $request->exec };
  }
  elsif($m = $self->mason_request)
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
