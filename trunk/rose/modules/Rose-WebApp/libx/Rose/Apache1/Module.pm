package Rose::Apache::Module;

use strict;

use Apache;
use Apache::File;
use Apache::Request;
use Apache::Util qw(:all);
use Apache::Constants qw(:response :methods :http :types);

use Rose::Apache::Notes;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Debug = undef;

use Class::MakeMethods::Template::Hash
(
  scalar =>
  [
    'apache_request',
    'mason_request',

    'notes',
    'apr',

    'error',
    'status',
    'done',
  ],
);

use Rose::Object::MakeMethods::Generic
(    
  hash =>
  [
    params       => { interface => 'get_set_inited' },
    param        => { hash_key  => 'params' },
    param_names  => { interface => 'keys', hash_key => 'params' },
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

  $self->{'request'} ||= Apache->request;
  $self->{'notes'}   ||= Rose::Apache::Notes->new();
}

sub handler($$)
{
  my($self, $r) = @_;

  $self = $self->new($r)  unless(ref($self));

  $self->sanity_check() || return $self->status;

  return OK;
}

sub request
{
  $_[0]->{'apache_request'} = $_[1]  if(@_ > 1);
  return $_[0]->{'apache_request'};
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

  my($apr) = $self->{'apr'} = Apache::Request->new($r || $self->{'request'});

  # Parse the form data, if any
  my($status) = $apr->parse();

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

sub _import_params
{
  my($self, $apr) = @_;

  my(%hash);

  foreach my $param ($apr->param())
  {
    my(@vals) = $apr->param($param);

    if(@vals > 1)
    {
      $Debug && print STDERR "$param = array(", join(', ', @vals), ")\n";
      $hash{$param} = \@vals;
    }
    else
    {
      $Debug && print STDERR "$param = scalar($vals[0])\n";
      $hash{$param} = $vals[0];
    }
  }

  return $self->{'params'} = \%hash;
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

1;
