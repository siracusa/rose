package Rose::WebApp::Server::Module::Apache1;

use strict;

use Apache();
use Apache::File();
use Apache::Request();
use Apache::Util qw(:all);
use Apache::Constants qw(:response :methods :http :types);

use Rose::WebApp::Server;
use Rose::WebApp::Server::Notes;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'request',
    'apr',

    'error',
    'status',
    'done',
  ],
);

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' =>
  [
    'server',
    'notes',
  ],

  hash =>
  [
    params       => { interface => 'get_set' },
    param        => { hash_key  => 'params' },
    param_names  => { interface => 'keys',   hash_key => 'params' },
    param_values => { interface => 'values', hash_key => 'params' },
    param_exists => { interface => 'exists', hash_key => 'params' },
    delete_param => { interface => 'delete', hash_key => 'params' },
  ],
);

sub init
{
  my($self) = shift;

  @_ = (request => $_[0])  if(@_ == 1);

  $self->SUPER::init(@_);

  $self->{'server'} ||= $self->init_server;
  $self->{'notes'}  ||= $self->init_notes;
}

sub init_server { Rose::WebApp::Server->new(apache_request => $_[0]->{'request'} ||= Apache->request) }
sub init_notes  { Rose::WebApp::Server::Notes->new }

sub handler($$)
{
  my($self, $r) = @_;

  $self = $self->new($r)  unless(ref($self));

  $self->sanity_check() || return $self->status;

  return OK;
}

sub return
{
  my($self, $status) = @_;

  $self->{'status'} = $status;
  $self->{'done'}   = 1;
}

sub parse_query
{
  my($self, $r) = @_;

  my $apr = $self->{'apr'} = Apache::Request->new($r || $self->{'request'});

  # Parse the form data, if any
  my $status = $apr->parse();

  # Puke if the submission has errors
  unless($status == OK)
  {
    $apr->custom_response($status, $apr->notes("error-notes"));
    $self->return($status);
    return;
  }

  # Import parameters
  my %params;

  foreach my $param ($apr->param())
  {
    my(@vals) = $apr->param($param);

    if(@vals > 1)
    {
      $Debug && print STDERR "$param = array(", join(', ', @vals), ")\n";
      $params{$param} = \@vals;
    }
    else
    {
      $Debug && print STDERR "$param = scalar($vals[0])\n";
      $params{$param} = $vals[0];
    }
  }

  $self->{'params'} = \%params;

  return 1;
}

sub sanity_check
{
  my($self) = shift;

  my($r) = $self->{'request'};

  my($method_number) = $r->method_number();

  # If this is not a POST request
  if($method_number != M_POST)
  {
    # Chuck the HTTP/1.1 request body, if any
    if((my $ret = $r->discard_request_body) != OK)
    {
      $self->return($ret);
      return;
    }
  }

  # Make sure apache handles this type of request
  if($method_number == M_INVALID)
  {
    $r->log_error('Invalid method in request ', $r->the_request);
    $self->return(NOT_IMPLEMENTED);
    return;
  }

  # Checking for server options?  That's not us.
  if($method_number == M_OPTIONS)
  {
    $self->return(DECLINED);
    return;
  }

  # Sure, why not...
  $r->header_out('X-Module-Sender' => ref($self));

  return(1);
}

sub return_file
{
  my($self, $file) = @_;

  my $r = $self->request or die "Could not get request for $self";

  my $fh = Apache::File->new($r->filename($file));

  unless($fh)
  {
    $r->log->error("file permissions deny server access: ", 
                   $r->filename);
    return FORBIDDEN;
  }

  $r->update_mtime(-s $r->finfo);
  $r->set_last_modified;
  $r->set_etag;

  if((my $rc = $r->meets_conditions) != OK)
  {
    return $rc;
  }

  $r->set_content_length;
  $r->send_http_header;

  $r->send_fd($fh)  unless($r->header_only);

  close $fh;

  return OK;
}

sub serve_static_file
{
  my($class, $r) = @_;

  # Example 9.2 in the eagle book

  if((my $rc = $r->discard_request_body) != OK)
  {
    return $rc;
  }

  if($r->method_number == M_INVALID)
  {
    $r->log->error("Invalid method in request ", $r->the_request);
     return NOT_IMPLEMENTED;
  }

  if($r->method_number == M_OPTIONS)
  {
    return DECLINED; # http_core.c:default_handler() will pick this up
  }

  if($r->method_number == M_PUT)
  {
    return HTTP_METHOD_NOT_ALLOWED;
  }

  unless(-e $r->finfo)
  {
    $r->log->error("File does not exist: ", $r->filename);
    return NOT_FOUND;
  }

  if($r->method_number != M_GET)
  {
    return HTTP_METHOD_NOT_ALLOWED;
  }

  my $fh = Apache::File->new($r->filename);

  unless($fh)
  {
    $r->log->error("file permissions deny server access: ", 
                   $r->filename);
    return FORBIDDEN;
  }

  $r->update_mtime(-s $r->finfo);
  $r->set_last_modified;
  $r->set_etag;

  if((my $rc = $r->meets_conditions) != OK)
  {
    return $rc;
  }

  $r->set_content_length;
  $r->send_http_header;

  $r->send_fd($fh)  unless($r->header_only);

  close $fh;

  return OK;
}

1;
