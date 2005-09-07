package Rose::WebSite::App;

use strict;

use Carp;

use Apache;
use Apache::Constants qw(OK DECLINED NOT_FOUND SERVER_ERROR);
use Rose::WebSite;

use Rose::WebSite::App::Page;
use Rose::WebSite::App::Comp;
use Rose::WebSite::App::Form;

our $ACTION_PATH_PREFIX = Rose::WebSite->action_path_prefix;

our $MASON_ERROR_MODE   = Apache->server->dir_config('MasonErrorMode');
our $MASON_ERROR_FORMAT = ($MASON_ERROR_MODE eq 'fatal') ? 'text' : 'html';

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Debug = 0;

use Class::MakeMethods::Template::Hash
(
  'scalar' =>
  [
    'root_uri',

    'redispatched_from',

    'requires_login_message',

    'message',
    'error',

    'status',
  ],

  'boolean --get_set' =>
  [
    'requires_secure',
    'requires_login',
    'auto_print',
    'redispatched',
    'is_main',
    'http_header_sent',
  ],
);

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' =>
  [
    'apr',
    'mason_interp',
    'apache_request',
    'user',

    'default_action',
    'action_method_prefix',
    'app_param_prefix',

    'default_form_action_method',
    'client_is_rose_internal',

    'call_count',
  ],

  hash =>
  [
    param_names  => { interface => 'keys',   hash_key => 'params' },
    param_values => { interface => 'values', hash_key => 'params' },
    param_exists => { interface => 'exists', hash_key => 'params' },
    delete_param => { interface => 'delete', hash_key => 'params' },

    action_args       => { interface => 'get_set_inited' },
    action_arg        => { hash_key => 'action_args' },
    action_arg_exists => { interface => 'exists', hash_key => 'action_args' },
    delete_action_arg => { interface => 'delete', hash_key => 'action_args' },

    #page_paths => { interface => 'get_set_all' },
    #page_path  => { hash_key => 'page_paths' },

    page => { hash_key => 'pages' },
    comp => { hash_key => 'comps' },
    form => { hash_key => 'forms' },

    page_exists => { interface => 'exists', hash_key => 'pages' },
    form_exists => { interface => 'exists', hash_key => 'forms' },

    action_dispatch_table => { interface => 'get_set_all' },
    action_dispatch       => { hash_key => 'action_dispatch_table' },

    uri_dispatch_table => { interface => 'get_set_all' },
    uri_dispatch       => { hash_key => 'uri_dispatch_table' },

    action_uri_dispatch_table => { interface => 'get_set_all' },
    action_uri_dispatch       => { hash_key => 'action_uri_dispatch_table' },
  ],

  array =>
  [
    previous_actions => { interface => 'get_set_inited' },
  ]
);

sub init_client_is_rose_internal { Rose::WebSite->client_is_rose_internal }

sub init_apr
{
  my($self, $r) = @_;
  return Apache::Request->new($r || $self->apache_request,
                              DISABLE_UPLOADS => 1);
}

sub init_mason_interp   { Rose::WebSite->mason_interp }
sub mason_request       { Rose::WebSite->mason_request }

sub init_apache_request { Apache->request }
sub init_user           { Rose::WebSite->user }

sub init_default_action        { undef }
sub init_action_method_prefix  { 'do_' }

sub init_default_form_action_method { 'post' }
sub init_app_param_prefix { 'APP_' }
sub init_call_count { 0 }

sub page_class { 'Rose::WebSite::App::Page' }

sub translate_uri { $_[1] }

sub no_cache { shift->apache_request->no_cache((@_) ? $_[0] : 1) }

sub send_http_header
{
  my($self) = shift;

  unless($self->http_header_sent)
  {
    #$Debug && warn "send_http_header ", join(':', (caller())[0,2]), " - ", ref $self, "\n";
    my $r = $self->apache_request;

    #if($r->is_initial_req)
    #{
      $r->send_http_header;
      $self->http_header_sent(1);
    #}
  }
}

sub action
{
  my($self) = shift;

  if(@_)
  {
    if(defined $self->{'action'})
    {
      push(@{$self->{'previous_actions'}}, $self->{'action'});
    }

    return $self->{'action'} = $_[0];
  }

  return $self->{'action'};
}

sub previous_action
{
  (@{$_[0]->{'previous_actions'}}) ? $_[0]->{'previous_actions'}[-1] : undef;
}

sub clear { $_[0]->refresh }

sub refresh
{
  my($self) = shift;

  $self->{'mason_interp'}      = undef;
  $self->{'apache_request'}    = undef;
  $self->{'user'}              = undef;
  $self->{'params'}            = {};
  $self->{'action'}            = undef;
  $self->{'previous_actions'}  = [];
  $self->{'action_args'}       = {};
  $self->{'redispatched'}      = 0;
  $self->{'redispatched_from'} = undef;
  $self->{'http_header_sent'}  = 0;
  $self->{'call_count'}        = 0;

  $self->{'client_is_rose_internal'} = undef;

  $self->{'output'} = '';

  $self->{'message'} = $self->{'error'} = $self->{'public_error'} = undef;

  $self->{'status'} = undef;

  $self->reset_forms;
}

sub reset_forms
{
  my($self) = shift;

  foreach my $form ($self->forms)
  {
    $form->reset;
  }
}

sub clear_error
{
  $_[0]->public_error(undef);
  $_[0]->error(undef);
}

sub do
{
  my($self, $action, %args) = @_;

  croak "Missing action argument"  unless(defined $action);

  $self->action_args(\%args)  if(@_ > 2);
  $self->action($action);
  $self->run;
}

sub require_secure { Rose::WebSite->require_secure }

sub require_login
{
  my($self) = shift;
  my %args = (@_ == 1) ? (message => $_[0]) : (@_);
  $args{'message'} ||= $self->requires_login_message;
  Rose::WebSite->require_login(%args);
}

sub run
{
  my($self) = shift;

  $self->require_secure() or return 1
    if($self->requires_secure);

  $self->require_login() or return 1
    if($self->requires_login);

  my $action = $self->action;

  unless(defined $action)
  {
    # Try to determine action based on the URI  
    my $uri = $self->dispatch_uri;
    my $action_uri = $self->dispatch_action_uri;

    my $uri_table        = $self->uri_dispatch_table;
    my $action_uri_table = $self->action_uri_dispatch_table;

    # 1. Check the URI dispatch table
    if(exists $uri_table->{$uri})
    {
      $action = $uri_table->{$uri};
    }
    # 2. Check the action URI dispatch table
    elsif(exists $action_uri_table->{$action_uri})
    {
      $action = $action_uri_table->{$action_uri};
    }
    # 3. Check for a method named like the URI, sans "/"
    # (This is a pretty big security risk...)
    #elsif($self->can(substr($uri, 1)))
    #{
    #  $action = substr($uri, 1);
    #}

    $self->action($action);
  }

  $action ||= $self->default_action;

  if(defined $action)
  {
    $self->start;

    my %args = $self->action_args;
    my $ret = $self->perform_action(action => $action, 
                                    args   => \%args);
    $self->finish;

    return  unless($ret);

    $self->status(OK)  unless(defined $self->status);
    return 1;
  }
  else # default to file-based dispatch
  {
    return $self->file_based_dispatch();
  }
}

sub file_based_dispatch
{
  my($self) = shift;

  $self->start;

  my $uri  = Rose::WebSite->requested_uri;
  my $path = Rose::WebSite->page_path($uri);

  #$Debug && warn "file_based_dispatch: _comp($path, ", join(', ', $self->params), ")\n";
  $self->_comp($self->translate_uri($path), $self->params);

  $self->status(OK)   unless(defined $self->status);

  $self->finish;

  return 1;
}

sub redispatch
{
  my($self, %args) = @_;

  %args = (action => $_[1])  if(@_ == 2);

  # Use params to fill in action args
  #foreach my $param ($self->param_names)
  #{
  #  $args{$param} = $self->param($param)  unless(exists $args{$param});
  #}

  # Common case of passing messages and errors through to nested app calls
  $self->app_param(message => $self->message);
  $self->app_param(error => $self->error);

  # Common case of passing action args through to nested app calls
  $self->app_param(action_args => scalar $self->action_args);

  # Pass any other arguments through to nested app calls
  foreach my $arg (keys %args)
  {
    $self->app_param($arg => $args{$arg});
  }

  $self->redispatched_from($self->action);

  $Debug && warn "REDISPATCH: ($args{'action'})\n";
  $self->clear_output;
  $self->delete_app_param('action');
  $self->action($args{'action'});

  $self->redispatched(1);
  $self->run;
}

sub clear_output
{
  $_[0]->{'output'} = '';
}

sub output
{
  my($self) = shift;

  #$Debug && warn "append ", length $_[0], " chars from output(): ", 
  #               substr($_[0], 0, 15), "\n"  if(@_);

  $self->{'output'} .= join('', grep { length } @_)  if(@_);

  #$Debug && warn "total output = ", length $self->{'output'}, " chars\n"  if(@_);

  return $self->{'output'};
}

sub _comp
{
  my($self) = shift;

  my($buffer, $m);

  if($m = $self->mason_request)
  {
    unless($m->interp->comp_exists($_[0]))
    {
      $self->apache_request->log_error("Component does not exist: $_[0]");
      $self->status(NOT_FOUND);
      return 0;
    }

    $m->interp->set_global('app' => $self);
    eval { $buffer = $m->scomp(@_) };
  }
  else
  {
    my $interp = $self->mason_interp;

    unless($interp->comp_exists($_[0]))
    {
      $self->apache_request->log_error("Component does not exist: $_[0]");
      $self->status(NOT_FOUND);
      return 0;
    }

    $interp->out_method(\$buffer);
    $interp->set_global('app' => $self);

    eval
    {
      my $comp = shift;
      $interp->set_global('app' => $self);
      $m = $interp->make_request(comp => $comp, args => \@_);
      $m->error_mode($MASON_ERROR_MODE);
      $m->error_format($MASON_ERROR_FORMAT);
      $m->exec;
    };
  }

  # handle exception, which may be an HTML::Mason::Exception::Aborted object
  if(my $err = $@)
  {
    if(ref $err && $err->isa('HTML::Mason::Exception::Aborted'))
    {
      warn "Execution of component '$_[0]' aborted! - $err";
      return;
    }
    else
    {
      warn "Execution of component '$_[0]' failed! - $err";
    }

    $self->status(SERVER_ERROR);
    return;
  }

  if($self->{'call_count'} != 1 || $self->auto_print) # || $m)
  {
    #$Debug && warn join(', ', map { "$_ = $self->{$_}" } qw(is_main redispatched comp_calls)), "\n";

    $self->send_http_header  if($self->is_main);

    #$Debug && warn "print ", length $buffer, " chars from _comp(): ", substr($buffer, 0, 15), "\n";

    print $buffer;
  }
  else
  {
    #$Debug && warn "add to output ", length $buffer, " chars from _comp(): ", substr($buffer, 0, 15), "\n";
    $self->output($buffer);
  }

  return 1;
}

sub inc_call_count { ++$_[0]->{'call_count'} }
sub dec_call_count { --$_[0]->{'call_count'} }

sub start
{ 
  my($self) = shift;

  my $count = $self->inc_call_count;

  #$Debug && warn "START(@{[ $count - 1 ]} -> $count) - ", join(':', (caller())[0,2]), "\n";  
}

sub finish
{
  my($self) = shift;

  my $count = $self->dec_call_count;

  #$Debug && warn "FINISH(@{[ $count + 1 ]} -> $count) - ", join(':', (caller())[0,2]), "\n";

  croak "Negative call count ($self->{'call_count'}) in $self"
    if($count < 0);

  if($count == 0 && $self->status == OK)
  {
    $self->send_http_header  if($self->is_main);

    #$Debug && warn "print ", length $self->{'output'}, " chars from finish(): ", 
    #                substr($self->{'output'}, 0, 15), "...\n";

    print $self->output;
  }

  $self->status(OK)  unless(defined $self->status);
}

sub perform_action
{
  my($self, %args) = @_;

  $args{'action'} = $_[1]  if(@_ == 2);

  my $action = $args{'action'} or die "Missing action argument";
  my $args   = $args{'args'} || {};

  my $action_table = $self->action_dispatch_table;

  # 1. Check the action dispatch table
  if(exists $action_table->{$action})
  {
    my $method = $action_table->{$action};
    return $self->$method(%$args);
  }
  # 2. Check for an (action-prefixed) method with the same name
  elsif($self->can($self->action_method_prefix . $action))
  {
    my $method = $action_table->{$action} = $self->action_method_prefix . $action;
    return $self->$method(%$args);
  }
  # 3. Check for a page with that name
  elsif($self->page_exists($action))
  {
    return $self->show_page(name => $action, page_args => $args);
  }
  # 4. Check for a form with that name
  elsif($self->form_exists($action))
  {
    return $self->show_form(name => $action, view_args => $args);
  }
  else # default to file-based dispatch
  {
    croak "Nothing defined for action '$action'";
  }
}

sub redirect_to_page
{
  my($self, %args) = @_;

  if(@_ == 2)
  {
    %args = (ref $_[1]) ? (page => $_[1]) : (name => $_[1]);
  }

  my $page = $args{'page'} || $self->page($args{'name'}) 
    or die "Could not get page named '$args{'name'}'";

  Rose::WebSite->redirect($page->page_uri);
}

sub show_page
{
  my($self, %args) = @_;

  if(@_ == 2)
  {
    %args = (ref $_[1]) ? (page => $_[1]) : (name => $_[1]);
  }

  $Debug && warn "show_page(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";

  my $interp = $self->mason_interp;

  my $page = $args{'page'} || $self->page($args{'name'}) 
    or die "Could not get page named '$args{'name'}'";

  my $page_path = $page->page_path or die "No path for page '$args{'name'}'";

  #$Debug && warn "interp->load($page_path)\n";
  #my $page_comp = $interp->load($page_path) || 
  #  croak "Could not load page comp '$page_path'";

  my $page_args = $args{'page_args'} ||= {};

  foreach my $name ($page->form_names)
  {
    $page_args->{$name} = $self->prepare_form($name);
  }

  $page_args->{$self->app_param_name('params')} = $self->params;

  $page_args->{'message'} ||= $self->message || $self->stash_message;
  $page_args->{'error'} ||= $self->public_error || $self->stash('public_error') || $self->stash_error;

  $self->_comp($self->translate_uri($page_path), %{$page_args});
}

sub show_comp
{
  my($self, %args) = @_;

  %args = (name => $_[1])  if(@_ == 2);

  $Debug && warn "show_comp(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";
  my $interp = $self->mason_interp;

  my $comp = $self->comp($args{'name'}) 
    or die "Could not get comp named '$args{'name'}'";

  my $comp_path = $comp->comp_path or die "No path for comp '$args{'name'}'";

  #$Debug && warn "interp->load($comp_path)\n";
  #my $comp_comp = $interp->load($comp_path) || 
  #  croak "Could not fetch comp '$comp_path'";

  my $comp_args = $args{'comp_args'} ||= {};

  foreach my $name ($comp->form_names)
  {
    $comp_args->{$name} = $self->prepare_form($name);
  }

  $comp_args->{$self->app_param_name('params')} = $self->params;

  $comp_args->{'message'} ||= $self->message || $self->stash_message;
  $comp_args->{'error'} ||= $self->public_error || $self->stash('public_error');

  $self->_comp($self->translate_uri($comp_path), %{$comp_args});
}

# sub show_file
# {
#   my($self, $path, %args) = @_;
# 
#   $self->start;
#   $self->_comp($self->translate_uri($path), %args);
#   $self->finish;
#   
#   return 1;
# }

sub prepare_form
{
  my($self, %args) = @_;

  if(@_ == 2)
  {
    %args = (ref $_[1]) ? (form => $_[1]) : (name => $_[1]);
  }

  $Debug && warn "prepare_form(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";
  my $params = $self->params;

  my $form = $args{'form'} || $self->form($args{'name'})
    or die "Could not get form named '$args{'name'}'";

  my $html_form = $form->html_form or die "Missing form object";

  unless(!$form->should_prepare || $form->prepared)
  {
    unless(!$form->should_init || $args{'no_init'})
    {
      $html_form->params($params);

      my $no_clear = (exists $args{'no_clear'}) ? $args{'no_clear'} : 
                       !$form->should_clear_on_init;

      $html_form->reset  if($no_clear);
      $html_form->init_fields(no_clear => $no_clear);
    }

    unless(!$form->should_validate || $args{'no_validate'})
    {
      unless(!keys %$params || $html_form->validate)
      {
        my $error = $html_form->error || $html_form->error('One or more fields have errors.');
        $self->error($error);
      }
    }

    if($args{'prepare'})
    {
      my(@methods, %method_args);

      if(ref $args{'prepare'} eq 'HASH')
      {
        while(my($method, $args) = each(%{$args{'prepare'}}))
        {
          push(@methods, $method);

          $method_args{$method} = (ref $args eq 'HASH') ? [ %$args ] :
                                  (ref $args eq 'ARRAY') ? $args : [ $args ];
        }
      }
      elsif(ref $args{'prepare'} eq 'ARRAY')
      {
        @methods = @{$args{'prepare'}};
      }
      elsif(!ref  $args{'prepare'})
      {
        @methods = $args{'prepare'};
      }
      else { croak "Bad 'prepare' parameter value -  $args{'prepare'}" }

      foreach my $method (@methods)
      {
        $html_form->$method((exists $method_args{$method}) ? @{$method_args{$method}} : ());
      }
    }

    $form->prepared(1);
  }

  return $form;
}

sub show_form
{
  my($self, %args) = @_;

  if(@_ == 2)
  {
    %args = (ref $_[1]) ? (form => $_[1]) : (name => $_[1]);
  }

  $Debug && warn "show_form(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";
  my $m = $self->mason_interp;

  my $form = $args{'form'} || $self->prepare_form(name => $args{'name'}, prepare => $args{'prepare'});

  my $html_form = $args{'html_form'} || $form->html_form;

  my $view_path = $args{'view_path'} || $form->view_path 
    or die "No view path for form $form";

  #$Debug && warn "interp->load($view_path)\n";
  #my $view_comp = $interp->load($view_path) || 
  #  croak "Could not load form view '$view_path'";

  my $view_args = $args{'view_args'} ||= {}; #{ %{$self->params} };

  if($args{'name'})
  {
    $view_args->{$args{'name'}} ||= $html_form;
  }
  else
  {
    $view_args->{$form->name} ||= $html_form;
  }

  $view_args->{'html_form'} ||= $html_form;
  $view_args->{'message'}   ||= $self->message || $self->stash_message;
  $view_args->{'error'}     ||= $self->public_error || $html_form->error || 
                                $self->stash('public_error');

  $self->_comp($self->translate_uri($view_path), %$view_args);
}

sub return { shift->output(join('', @_)) }

sub return_error
{
  my($self) = shift;

  $self->public_error(join('', @_))  if(@_);

  $self->return('<div class="error">ERROR: ' . $self->public_error . '</div>');
}

sub return_error_page
{
  my($self) = shift;

  $self->clear_output;

  $self->output(<<"EOF");
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Error</title>
</head>
<body>
EOF

  $self->return_error(@_);

  $self->output('</body></html>');
}

sub redirect { shift; Rose::WebSite->redirect(@_) }
sub internal_redirect { shift; Rose::WebSite->internal_redirect(@_) }

sub params_exist { scalar keys %{$_[0]->{'params'}} }

sub params
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'params'} = { %{$_[0]} }; 
    }
    elsif(@_ % 2 == 0)
    {
      $self->{'params'} = { @_ };
    }
    else
    {
      croak(ref($self), '::params() - got odd number of arguments: ');
    }

    my %cleaned_params;

    my $prefix_re = qr{^@{[ $self->app_param_prefix ]}(.+)};

    while(my($param, $value) = each %{$self->{'params'}})
    {
      #$Debug && warn "App arg $param = $value\n";
      #if($param =~ /^APP_(.+)/)
      if($param =~ /$prefix_re/)
      {
        my $method = $1;
        next  unless($self->can($method));
        #$Debug && warn "$self->$method($value)\n";
        $self->$method($value);
      }
      else
      {
        # Handle image map clicks
        $param =~ s/\.[xy]$//; # foo.x and foo.y -> foo

        #$Debug && warn "$self set app arg $param = $value\n";
        $cleaned_params{$param} = $value;
      }
    }

    $self->{'params'} = \%cleaned_params;
  }

  return (wantarray) ? %{$self->{'params'}} : $self->{'params'};
}

sub param
{
  my($self, $param, $value) = @_;

  if(@_ == 2)
  {
    if(exists $self->{'params'}{$param})
    {
      if(wantarray)
      {
        if(ref $self->{'params'}{$param})
        {
          return @{$self->{'params'}{$param}};
        }

        return ($self->{'params'}{$param});
      }

      return $self->{'params'}{$param};
    }

    return;
  }
  elsif(@_ == 3)
  {
    return $self->{'params'}{$param} = $value;
  }

  croak(ref($self), '::param() requires a param name plus an optional value');
}

sub app_param_name { $_[0]->app_param_prefix . $_[1]  }

sub app_param
{
  my($self, @args) = @_;

  $args[0] = $self->app_param_prefix . $args[0]  if(@args);

  $self->param(@args);
}

sub delete_app_param
{
  my($self, @args) = @_;

  $args[0] = $self->app_param_prefix . $args[0]  if(@args);

  $self->delete_param(@args);
}

# sub page_uri
# {
#   my($self, $page) = @_;
#   
#   my $path = $self->page_path($page) or return undef;
# 
#   return Rose::WebSite->page_uri($path);
# }

sub build_action_uri
{
  my($self, $action) = @_;

  return Rose::WebSite->action_uri(root => $self->root_uri, action => $action);
}

sub dispatch_action_uri
{
  my $uri = $_[0]->dispatch_uri;

  if($uri =~ s{^$ACTION_PATH_PREFIX}{}o)
  {
    $uri = '/'  unless(length $uri);
    return $uri;
  }

  return undef;
}

sub dispatch_uri
{
  my($self) = shift;

  my $uri = Rose::WebSite->requested_uri;
  my $root_uri = $self->root_uri;
  $uri =~ s/^$root_uri//;

  $uri = '/'  unless(length $uri);

  return $uri;
}

sub public_error
{
  my($self) = shift;

  if(@_)
  {
    $self->{'public_error'} = shift;
  }

  return $self->{'public_error'} || $self->error;
}

sub pages
{
  my($self) = shift;

  if(@_)
  {
    my $args;

    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $args = { %{$_[0]} }; 
    }
    elsif(@_ % 2 == 0)
    {
      $args = { @_ };
    }
    else
    {
      croak(ref($self), '::pages() - got odd number of arguments');
    }

    my %pages;

    my $page_class = $self->page_class;

    while(my($name, $value) = each(%$args))
    {
      if(ref $value eq 'HASH')
      {
        $pages{$name} = $page_class->new(%$value);
      }
      elsif(ref $value && $value->isa('Rose::WebSite::App::Page'))
      {
        $pages{$name} = $value;
      }
      else
      {
        croak(ref($self), "::pages() - invalid page argument value: '$value'");
      }
    }

    $self->{'pages'} = \%pages;
  }

  return (wantarray) ? values %{$self->{'pages'}} : $self->{'pages'};
}

sub comps
{
  my($self) = shift;

  if(@_)
  {
    my $args;

    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $args = { %{$_[0]} }; 
    }
    elsif(@_ % 2 == 0)
    {
      $args = { @_ };
    }
    else
    {
      croak(ref($self), '::comps() - got odd number of arguments');
    }

    my %comps;

    while(my($name, $value) = each(%$args))
    {
      if(ref $value eq 'HASH')
      {
        $comps{$name} = Rose::WebSite::App::Comp->new(%$value);
      }
      elsif(ref $value && $value->isa('Rose::WebSite::App::Comp'))
      {
        $comps{$name} = $value;
      }
      else
      {
        croak(ref($self), "::comps() - invalid comp argument value: '$value'");
      }
    }

    $self->{'comps'} = \%comps;
  }

  return (wantarray) ? values %{$self->{'comps'}} : $self->{'comps'};
}

sub forms
{
  my($self) = shift;

  if(@_)
  {
    my $args;

    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $args = { %{$_[0]} }; 
    }
    elsif(@_ % 2 == 0)
    {
      $args = { @_ };
    }
    else
    {
      croak(ref($self), '::forms() - got odd number of arguments');
    }

    my %forms;

    while(my($name, $value) = each(%$args))
    {
      if(ref $value eq 'HASH')
      {
        $value->{'action_method'} = $self->default_form_action_method
          unless(exists $value->{'action_method'});

        $forms{$name} = Rose::WebSite::App::Form->new(%$value);
      }
      elsif(ref $value && $value->isa('Rose::WebSite::App::Form'))
      {
        $forms{$name} = $value;
      }
      else
      {
        croak(ref($self), "::forms() - invalid form argument value: '$value'");
      }

      $forms{$name}->name($name);
    }

    $self->{'forms'} = \%forms;
  }

  return (wantarray) ? values %{$self->{'forms'}} : $self->{'forms'};
}

sub delete_params { $_[0]->{'params'} = {} }

sub stash_message
{
  my($self) = shift;

  return $self->stash(message => $_[0])  if(@_);

  if(my $message = $self->stash('message'))
  {
    $self->clear_stash('message');
    return $message;
  }

  return undef;
}

sub stash_error
{
  my($self) = shift;

  return $self->stash(error => $_[0])  if(@_);

  if(my $error = $self->stash('error'))
  {
    $self->clear_stash('error');
    return $error;
  }

  return undef;
}

# This is both a class method and an object method

sub stash
{
  my($self) = shift;

  my %args = (@_ == 2) ? (name => $_[0], value => $_[1]) :
             (@_ == 1) ? (name => $_[0]) : @_;

  my $session;

  my $domain = $args{'domain'};

  if(ref $self)
  {
    $domain ||= ref $self;
    $session = $self->user->session or croak "Could not get user's session";
  }
  else
  {
    $domain ||= $self;
    $session = Rose::WebSite->user->session;
  }

  die "Missing name argument"  unless($args{'name'});

  if(@_ == 1)
  {
    return $session->stash(domain => $domain, name => $args{'name'});
  }
  elsif(@_)
  {
    die "Missing value argument"  unless(exists $args{'value'});
    return $session->stash(domain => $domain, name => $args{'name'}, value => $args{'value'});
  }

  return undef;
}

# This is both a class method and an object method

sub clear_stash
{
  my($self) = shift;

  my($session, $domain);

  if($domain = ref $self)
  {
    $session = $self->user->session or croak "Could not get user's session";
  }
  else
  {
    $domain = $self;
    $session = Rose::WebSite->user->session;
  }

  @_ = (name => $_[0])  if(@_ == 1);

  $session->clear_stash(domain => $domain, @_);
}

1;
