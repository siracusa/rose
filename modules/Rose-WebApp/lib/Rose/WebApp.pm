package Rose::WebApp;

use strict;

use Carp;
use Class::C3;

use Rose::WebApp::Server;
use Rose::WebSite;

use Rose::WebApp::Page;
use Rose::WebApp::Comp;
use Rose::WebApp::Form;

use Rose::WebApp::Feature::Metadata;
use Rose::WebApp::Server::Constants qw(OK SERVER_ERROR);

use Rose::Object;
our @ISA = qw(Rose::Object);

Class::C3::initialize();

our $Debug = 0;

our $VERSION = '0.01_001';

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    view_type_classes => { interface => 'get_set_all' },
    view_type_class   => { interface => 'get_set', hash_key => 'view_type_classes' },
    delete_view_type_class => { interface => 'delete', hash_key => 'view_type_classes' },

    using_features => { interface => 'keys', hash_key => '_features' },
    using_feature  => { interface => 'get_set', hash_key => '_features' },
  ],

  inheritable_scalar => '_feature_use',
);

__PACKAGE__->_feature_use({});

__PACKAGE__->view_type_classes
(
  'mason' => 'Rose::WebApp::View::Mason',
);

use Rose::Object::MakeMethods::Generic
(
  'scalar' =>
  [
    'redispatched_from',
    'output_buffer',
    'message',
    'error',
    'status',
  ],

  'boolean' =>
  [
    'requires_secure',
    'auto_print',
    'redispatched',
    'http_header_sent',
  ],

  'scalar --get_set_init' =>
  [
    'root_uri',

    'page_class',
    'comp_class',
    'form_class',
    'website_class',

    'default_view_type',
    'default_action',
    'default_form_action_method',
    'default_to_file_based_dispatch',
    'action_path',
    'action_method_prefix',
    'action_uri_prefix',
  ],

  hash =>
  [
    param_names  => { interface => 'keys',   hash_key => 'params' },
    param_values => { interface => 'values', hash_key => 'params' },
    param_exists => { interface => 'exists', hash_key => 'params' },
    delete_param => { interface => 'delete', hash_key => 'params' },

    action_args       => { interface => 'get_set' },
    action_arg        => { hash_key => 'action_args' },
    action_arg_exists => { interface => 'exists', hash_key => 'action_args' },
    delete_action_arg => { interface => 'delete', hash_key => 'action_args' },

    page => { hash_key => 'pages' },
    comp => { hash_key => 'comps' },
    form => { hash_key => 'forms' },

    page_exists => { interface => 'exists', hash_key => 'pages' },
    comp_exists => { interface => 'exists', hash_key => 'forms' },
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

sub root_dir
{
  my($self) = shift;
  
  my $doc_root = $self->server->document_root;
  $doc_root =~ s{/$}{};
  
  my $root_uri = $self->root_uri;
  $root_uri = ''  if($root_uri eq '/');

  return "$doc_root/$root_uri";
}

sub root_uri_regex
{
  unless($_[0]->{'root_uri_regex'})
  {
    my $root_uri = $_[0]->root_uri;
    return $_[0]->{'root_uri_regex'} = qr(^$root_uri);
  }

  return $_[0]->{'root_uri_regex'};
}

sub action_uri_prefix_regex
{
  unless($_[0]->{'action_uri_prefix_regex'})
  {
    my $prefix = $_[0]->action_uri_prefix;
    return $_[0]->{'action_uri_prefix_regex'} = qr(^/$prefix);
  }

  return $_[0]->{'action_uri_prefix_regex'};
}

sub init_root_uri { shift->server->location }
sub init_action_uri_prefix { 'exec' }

sub server { shift->website->server(@_) }

sub init_default_action        { undef }
sub init_action_method_prefix  { 'do_' }

sub init_default_form_action_method { 'post' }

sub init_default_to_file_based_dispatch { 0 }

sub init_website_class { 'Rose::WebSite' }
*website = \&website_class;

sub init_form_class { 'Rose::WebApp::Form' }
sub init_comp_class { 'Rose::WebApp::Comp' }
sub init_page_class { 'Rose::WebApp::Page' }

sub init_default_view_type { 'mason' }

sub uri_to_path { $_[1] }
sub path_to_uri { $_[1] }

sub init_comp_error_mode { 'fatal' }

sub app_uri
{
  my($self) = shift;
  return $self->root_uri  unless(@_);
  my $uri = shift;
  $uri = "/$uri"  unless(index($uri, '/') == 0);
  return $self->root_uri . $uri;
}

sub app_url
{
  my($self) = shift;
  $self->website->site_url($self->app_uri(@_));
}

sub app_url_secure
{
  my($self) = shift;
  $self->website->site_url_secure($self->app_uri(@_));
}

sub app_url_insecure
{
  my($self) = shift;
  $self->website->site_url_insecure($self->app_uri(@_));
}

sub absolute_uri
{
  my($self) = shift;
  return $self->root_uri  unless(@_);
  my $uri = shift;
  return $uri  if(index($uri, '/') == 0);
  return $self->root_uri . "/$uri";
}

*absolute_path = \&absolute_uri;

sub absolute_url
{
  my($self) = shift;
  return $_[0]  if($_[0] =~ m{^\w+://});
  $self->website->site_url($self->absolute_uri(@_));
}

sub absolute_url_secure
{
  my($self) = shift;
  return $_[0]  if($_[0] =~ m{^\w+://});
  $self->website->site_url_secure($self->absolute_uri(@_));
}

sub absolute_url_insecure
{
  my($self) = shift;
  return $_[0]  if($_[0] =~ m{^\w+://});
  $self->website->site_url_insecure($self->absolute_uri(@_));
}

sub comp_error_mode
{
  my($self) = shift;

  if(@_)
  {
    unless($_[0] =~ /^(?:fatal|inline|log|silent)$/)
    {
      croak "Invalid comp error mode: $_[0]" 
    }

    return $self->{'comp_error_mode'} = $_[0];
  }

  return $self->{'comp_error_mode'} || $self->init_comp_error_mode;
}

sub remote_user { shift->server->remote_user }

our %Features;

# Register bundled features
__PACKAGE__->register_features
(
  'self-starter'   => 'Rose::WebApp::SelfStarter',
  'inline-content' => 'Rose::WebApp::WithInlineContent',
  'logger'         => 'Rose::WebApp::WithLogger',
  'app-params'     => { class => 'Rose::WebApp::WithAppParams', isa_position => 'start' },
);

sub register_features
{
  my($self) = shift;

  my $class = ref $self || $self;

  if(@_ <= 1)
  {
    my $name = $self->normalize_feature_name(shift || $class->feature_name);

    if(exists $Features{$name})
    {
      return  if($Features{$name}->class eq $class); # already registered

      croak "The the class ", $Features{$name}->class, 
             " is already registered under the feature name '$name'";
    }

    $Features{$name} = Rose::WebApp::Feature::Metadata->new(class => $class, name => $name);
    return 1;
  }

  unless(@_ % 2 == 0)
  {
    croak "Odd number of arguments passed to register_subclass()";
  }

  while(@_)
  {
    my $name = shift or croak "Missing feature name";
    my $info = shift or croak "Missing feature information";

    $name = $self->normalize_feature_name($name);

    if($Features{$name})
    {
      croak "The the class $Features{$name} is already registered under the feature name '$name'";
    }

    if(!ref $info)
    {
      $Features{$name} = 
        Rose::WebApp::Feature::Metadata->new(class => $info, name => $name);
    }
    else
    {
      unless(ref $info eq 'HASH')
      {
        croak "Invalid feature information argument: $info";
      }

      $Features{$name} = 
        Rose::WebApp::Feature::Metadata->new(%$info, name => $name);
    }
  }

  return 1;
}

*register_subclass = \&register_features;
*register_feature  = \&register_features;

sub normalize_feature_name
{
  my($self_or_class, $name) = @_;
  $name =~ s/[^-\w:]+//g;
  return lc $name;
}

sub uses_feature
{
  my($self) = shift;

  my $class = ref $self || $self;
  
  if(@_ > 1)
  {
    my($name, $value) = @_;
    return $class->_feature_use->{$self->normalize_feature_name($name)} = $value;
  }

  return $class->_feature_use->{$self->normalize_feature_name($_[0])}
}

sub use_features
{
  my($class) = shift;

  my @feature_classes;

  foreach my $feature (@_)
  {
    my $name = $class->normalize_feature_name($feature);

    my $feature_meta = $Features{$name} 
      or croak "No feature registered under the name '$name'";

    my $feature_class = $feature_meta->class 
      or croak "Feature '$name' has no associated class";

    next  if($class->isa($feature_class));

    eval "use $feature_class";
    croak "Could not use feature '$feature' because the module ",
          "$feature_class failed to load - $@"  if($@);

    my $isa_pos = $feature_meta->isa_position;

    no strict 'refs';
    if($isa_pos eq 'start')
    {
      unshift(@{"${class}::ISA"}, $feature_class);
    }
    elsif($isa_pos eq 'end')
    {
      push(@{"${class}::ISA"}, $feature_class);
    }
    else
    {
      croak "Don't know how to honor ISA position '$isa_pos' for feature '$name'";
    }
#print STDERR "$class USES FEATURE $name\n";
    $class->uses_feature($name => 1);

    push(@feature_classes, $feature_class);
  }

  # Do per-featrue setup  
  foreach my $feature_class (@feature_classes)
  {
    $feature_class->feature_setup($class);
  }

  Class::C3::reinitialize();
}

sub send_http_header
{
  my($self) = shift;

  unless($self->http_header_sent)
  {
    #$Debug && warn "send_http_header ", join(':', (caller())[0,2]), " - ", ref $self, "\n";
    $self->server->send_http_header;
    $self->http_header_sent(1);
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

  $self->server(undef);

  $self->params({});
  $self->action(undef);
  $self->previous_actions([]);
  $self->action_args({});
  $self->redispatched(0);
  $self->redispatched_from(undef);
  $self->http_header_sent(0);

  $self->output_buffer('');

  $self->message(undef);
  $self->error(undef);
  $self->public_error(undef);

  $self->status(undef);

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
  $self->handle_request;
}

sub require_secure { shift->website_class->require_secure }

sub choose_view_type
{
  #my($self, $path) = @_;
  shift->default_view_type()
}

sub choose_view_manager
{
  my($self) = shift;

  my $type = $self->choose_view_type(@_);

  return $self->view_manager($type) or
         $self->default_view_manager or
         croak "Could not choose view manager for @_";
}

sub view_manager
{
  my($self) = shift;
  my($type) = shift;

  if(@_)
  {
    my $view = shift;
    $view->app($self);
    return $self->{'view_managers'}{$type} = $view;
  }

  my $view = $self->{'view_managers'}{$type};

  unless($view)
  {
    my $class = $self->view_type_class($type) 
      or croak "No class set for view type '$type'";

    #eval "require $class";
    #croak "Could not load $class - $@"  if($@);

    $view = $self->{'view_managers'}{$type} = $class->new(app => $self);
  }

  return $view;
}

sub default_view_manager
{
  my($self) = shift;

  my $type = $self->default_view_type
    or croak "No default view type set";

  return $self->view_manager($type);
}

sub view_managers
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'view_managers'} = $_[0];
    }
    else
    {
      croak "Odd dumber of arguments in call to view_managers()"
        if(@_ % 2);

       $self->{'view_managers'} = { @_ };
    }
  }

  return wantarray ? values(%{$self->{'view_managers'} ||= {}}) : 
                     ($self->{'view_managers'} ||= {});
}

sub reset_view_managers
{
  my($self) = shift;

  foreach my $view ($self->view_managers)
  {
    $view->reset;
  }
}

sub validate_run
{
  my($self) = shift;

  $self->require_secure() or return 0
    if($self->requires_secure);

  return 1;
}

sub choose_action
{
  my($self) = shift;

  my $action = $self->action;

  unless(defined $action)
  {
    CHOOSE: for(1)
    {
      # Try to determine action based on the URI  
      my $uri        = $self->dispatch_uri;
      my $uri_table  = $self->uri_dispatch_table;

      # 1. Check the URI dispatch table
      if(exists $uri_table->{$uri})
      {
        $action = $uri_table->{$uri};
        last CHOOSE;
      }

      $uri       = $self->dispatch_action_uri;
      $uri_table = $self->action_uri_dispatch_table;

      # 2. Check the action URI dispatch table
      if(exists $uri_table->{$uri})
      {
        $action = $uri_table->{$uri};
        last CHOOSE;
      }
      else # 3. Look for page with this URI
      {
        $uri = $self->server->requested_uri;

        foreach my $page ($self->pages)
        {
          if($uri eq $page->uri)
          {
            # Add URI dispatch entry so we don't have to do this again
            $self->uri_dispatch($uri => $page->name); 

            $action = $page->name;
            last CHOOSE;
          }
        }
      }
    }
  }

  return defined $action ? $action : $self->default_action;
}

sub handle_request
{
  my($self) = shift;

  local $Debug = 1  if($self->param('debug'));

  $self->validate_run() or return;

  my($action, $args) = $self->choose_action(@_) or return;

  if(defined $action)
  {
    $self->action($action);
    $self->action_args($args);

    $self->start;

    my $ret;

    eval
    {
      $ret = $self->perform_action(action => $action, 
                                   args   => $args || {});
    };

    if($@)
    {
      $self->handle_runtime_exception($@);
    }

    $self->finish;

    return 1;
  }
  elsif($self->default_to_file_based_dispatch)
  {
    return $self->file_based_dispatch();
  }
  else
  {
    $self->log_error("Finishing ", ref($self), "::run() without performing an action!");
    $self->status(SERVER_ERROR);
  }
}

sub handle_runtime_exception
{
  my($self, $exception) = @_;

  $self->log_error($exception);

  unless($self->http_header_sent)
  {
    $self->clear_output_buffer;
    $self->status(SERVER_ERROR);
  }
}

sub file_based_dispatch
{
  my($self) = shift;

  $self->start;

  my $uri  = $self->server->requested_uri;
  my $path = $self->uri_to_path($uri);

  eval
  {
    #$Debug && warn "file_based_dispatch: output_comp($path, ", join(', ', $self->params), ")\n";
    $self->output_comp($path, $self->params);
  };

  $self->status(OK)   unless(defined $self->status);

  $self->finish;

  return 1;
}

sub redispatch
{
  my($self, %args) = @_;

  %args = (action => $_[1])  if(@_ == 2);

  $self->redispatched_from($self->action);

  # Modify app based on args
  foreach my $arg (keys %args)
  {
    next  unless($self->can($arg));
    $self->$arg($args{$arg});
  }

  $Debug && warn "REDISPATCH: (", $self->action, ")\n";
  $self->clear_output_buffer;

  $self->redispatched(1);
  $self->handle_request;
}

sub clear_output_buffer
{
  $_[0]->output_buffer('');
}

sub add_output
{
  my($self) = shift;

  #$Debug && warn "append ", length $_[0], " chars from output(): ", 
  #               substr($_[0], 0, 15), "\n"  if(@_);

  $self->{'output_buffer'} .= join('',  grep { length } map { ref $_ ? $$_ : $_ } @_)  if(@_);

  #$Debug && warn "total output = ", length $self->{'output'}, " chars\n"  if(@_);

  if($self->auto_print)
  {
    $self->send_http_header;
    $self->server->print($self->{'output_buffer'});
    $self->{'output_buffer'} = undef;
  }

  return $self->{'output_buffer'};
}

sub output_comp
{
  my($self) = shift;
  my($path) = shift;

  my $view = $self->choose_view_manager($path);

  $Debug && warn "$view->output_comp(path => $path, args => @_)\n";
  $view->output_comp(path => $path, args => \@_)
    or $self->handle_comp_error($view);
}

sub run_comp
{
  my($self) = shift;
  my($path) = shift;

  my $view = $self->choose_view_manager($path);
  $view->run_comp(path => $path, args => \@_);
  return $view;
}

sub handle_comp_error
{
  my($self, $view) = @_;

  my $mode = $self->comp_error_mode;

  if($mode eq 'fatal')
  {
    if($self->auto_print && $self->http_header_sent)
    {
      $self->return_error($view->error);
      croak "$self->handle_comp_error(@_)";
    }
    else
    {
      $self->return_error_page($view->error);
    }
  }
  elsif($mode eq 'inline' && !$view->inlined_error)
  {
    #print STDERR "ADD OUTPUT: ", $view->error, "\n";
    $self->add_output($view->error);
  }

  if($mode ne 'silent')
  {
    $self->log_error($view->error);
  }
}

sub start { }

sub finish
{
  my($self) = shift;

  if($self->status == OK)
  {
    $self->send_http_header;

    #$Debug && warn "print ", length $self->{'output'}, " chars from finish(): ", 
    #                substr($self->{'output'}, 0, 15), "...\n";

    $self->server->print($self->output_buffer);

    $self->clear_output_buffer;
    $self->reset_view_managers;
  }

  $self->status(OK)  unless(defined $self->status);
}

sub print { shift->server->print(@_) }

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
  else # nothing defined: fail or fall through to file-based dispatch
  {
    unless($self->default_to_file_based_dispatch)
    {
      croak "Nothing defined for action '$action'";
    }
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
    or croak "Could not get page named '$args{'name'}'";

  my $uri = $self->absolute_uri($page->uri);

  $self->website->redirect($uri);
}

sub show_comp
{
  my($self, %args) = @_;

  %args = (name => $_[1])  if(@_ == 2);

  $Debug && warn "show_comp(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";

  my($comp, $comp_path);

  if($args{'name'})
  {
    $comp = $self->comp($args{'name'}) 
      or croak "Could not get comp named '$args{'name'}'";

    $comp_path = $comp->path or die "No path for comp '$args{'name'}'";
  }
  else
  {
    $comp_path = $args{'path'} or croak "Missing comp name or path";
  }

  $comp_path = $self->absolute_path($comp_path);

  my $comp_args = $args{'comp_args'} ||= {};

  $self->prepare_comp_args($comp || $comp_path, $comp_args);

  $self->output_comp($comp_path, %{$comp_args});
}

sub prepare_comp_args
{
  my($self, $comp, $comp_args) = @_;

  #$comp_args->{$self->app_param_name('params')} = $self->params;

  $comp_args->{'message'} ||= $self->message;      # || $self->stash_message;
  $comp_args->{'error'}   ||= $self->public_error; # || $self->stash('public_error');
}

sub show_page
{
  my($self, %args) = @_;

  %args = (name => $_[1])  if(@_ == 2);

  $Debug && warn "show_page(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";

  my($page, $page_path);

  if($args{'name'})
  {
    $page = $self->page($args{'name'}) 
      or croak "Could not get page named '$args{'name'}'";

    $page_path = $page->path or die "No path for page '$args{'name'}'";
  }
  else
  {
    $page_path = $args{'path'} or croak "Missing page name or path";
  }

  $page_path = $self->absolute_path($page_path);

  my $page_args = $args{'page_args'} ||= {};

  $self->prepare_page_args($page || $page_path, $page_args);

  foreach my $name ($page->form_names)
  {
    $page_args->{$name} = $self->prepare_form($name);
  }

  $self->output_comp($page_path, %{$page_args});
}

*prepare_page_args = \&prepare_comp_args;

sub prepare_form
{
  my($self, %args) = @_;

  if(@_ == 2)
  {
    %args = (ref $_[1]) ? (form => $_[1]) : (name => $_[1]);
  }

  $Debug && warn "prepare_form(", join(', ', map { "$_ = $args{$_}" } keys %args), ")\n";
  my $params = $self->params;

  my $form = $args{'form'} = $self->form($args{'name'})
    or die "Could not get form named '$args{'name'}'";

  my $html_form = $form->html_form;

  my $secure = $form->secure;
  my $action_uri;

  if(defined $secure)
  {
    $action_uri = $secure ? $self->absolute_url_secure($form->action_uri) :
                            $self->absolute_url_insecure($form->action_uri);
  }
  else
  {
    $action_uri = $self->absolute_uri($form->action_uri);
  }

  $html_form->action($action_uri);

  if(my $code = $form->preparer)
  {
    if(ref $code eq 'CODE')
    {
      $code->($self, %args);
    }
    else
    {
      $self->$code(%args);
    }

    $form->prepared(1);
  }
  else
  {
    if(my $code = $form->prepare_pre_hook)
    {
      if(ref $code eq 'CODE')
      {
        $code->($self, %args);
      }
      else
      {
        $self->$code(%args);
      }
    }

    $self->default_prepare_form($form, %args);

    if(my $code = $form->prepare_post_hook)
    {
      if(ref $code eq 'CODE')
      {
        $code->($self, %args);
      }
      else
      {
        $self->$code(%args);
      }
    }
  }

  return $form;
}

sub default_prepare_form
{
  my($self, $form, %args) = @_;

  my $html_form = $form->html_form or die "Could not get HTML form from $form ($args{'name'})";

  $html_form->build_form  if($form->build_on_prepare);

  my $params = $self->params;

  unless(!$form->should_prepare || $form->is_prepared)
  {
    unless(!$form->should_init || $args{'no_init'})
    {
      $html_form->params($params);

      my $no_clear = (exists $args{'no_clear_on_init'}) ? $args{'no_clear_on_init'} : 
                      !$form->clear_on_init;

      $html_form->reset  if($form->reset_on_init);
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

  my $view_args = delete $args{'view_args'} || {};

  my $form = $args{'form'} || $self->prepare_form(%args);

  my $html_form = $args{'html_form'} || $form->html_form;

  my $view_path = $args{'view_path'} || $form->view_path 
    or die "No view path for form $form";

  $view_path = $self->absolute_path($view_path);

  $self->prepare_form_args($form, $html_form, $view_args);

  $self->output_comp($view_path, %$view_args);
}

sub prepare_form_args
{
  my($self, $form, $html_form, $view_args) = @_;

  $view_args->{$form->name} ||= $html_form;

  $view_args->{'html_form'} ||= $html_form;

  $view_args->{'error'}     ||= $self->public_error || $html_form->error;
                                # || $self->stash('public_error');

  $view_args->{'message'} ||= $self->message; # || $self->stash_message;
  $view_args->{'error'}   ||= $self->public_error || $html_form->error; 
                              # || $self->stash('public_error');
}

sub return
{
  my($self) = shift;
  $self->add_output(join('', @_))  if(@_);
  $self->status(OK);
  croak "$self->return(@_)";
}

sub return_error
{
  my($self) = shift;
  my $error = @_ ? join('', @_) : $self->public_error;
  $self->log_error($error);
  $self->add_output('<div class="error">ERROR: ' . $self->server->escape_html($error) . '</div>');
  $self->status(OK);
}

sub return_error_page
{
  my($self) = shift;

  $self->clear_output_buffer;

  $self->add_output(<<"EOF");
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Error</title>
<style type="text/css">
.error { white-space: pre; font-family: Monaco, monospace }
</style>
</head>
<body>
EOF

  $self->return_error(@_);

  $self->add_output('</body></html>');

  #croak "$self->return_error_page(@_)";
}

sub log_level        { shift->server->log_level(@_) }
sub server_log_level { shift->server->log_level(@_) }

sub server_log_level_constant { shift->server->log_level_constant(@_) }

sub log_emergency { shift->server->log_emergency(@_) }
sub log_alert     { shift->server->log_alert(@_)     }
sub log_critical  { shift->server->log_critical(@_)  }
sub log_error     { shift->server->log_error(@_)     }
sub log_warning   { shift->server->log_warning(@_)   }
sub log_notice    { shift->server->log_notice(@_)    }
sub log_info      { shift->server->log_info(@_)      }
sub log_debug     { shift->server->log_debug(@_)     }

sub redirect { shift->website->redirect(@_) }
sub internal_redirect { shift->website->internal_redirect(@_) }

sub params_exist { scalar keys %{$_[0]->{'params'}} }

sub params
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'params'} = $_[0]; 
    }
    elsif(@_ % 2 == 0)
    {
      $self->{'params'} = { @_ };
    }
    else
    {
      croak(ref($self), '::params() - got odd number of arguments: ');
    }

    foreach my $param (keys %{$self->{'params'}})
    {
      #$Debug && warn "Check param $param\n";

      # Handle image map clicks: foo.x and foo.y -> foo
      if($param =~ /^(.+)\.[xy]$/)
      {
        $self->{'params'}{$1} = delete $self->{'params'}{$param}
      }
    }
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
  my($self) = shift;
  my($name) = shift;
  $name = $self->app_param_prefix . $name;
  return @_ ? ($self->{'app_params'}{$name} = shift) :
               $self->{'app_params'}{$name};
}

sub delete_app_param
{
  my($self) = shift;
  my($name) = shift;
  $name = $self->app_param_prefix . $name;
  delete $self->{'app_params'};
}

sub app_param_exists
{
  my($self) = shift;
  my($name) = shift;
  $name = $self->app_param_prefix . $name;
  return exists $self->{'app_params'}{$name};
}

sub action_uri
{
  my($self, $action) = @_;

  return join('/', $self->root_uri, $self->relative_action_uri($action));
}

sub relative_action_uri
{
  my($self, $action) = @_;

  return join('/', $self->action_uri_prefix, $action);
}

sub dispatch_action_uri
{
  my $uri   = $_[0]->dispatch_uri;
  my $regex = $_[0]->action_uri_prefix_regex;

  if($uri =~ s/$regex//)
  {
    $uri = '/'  unless(length $uri);
    return $uri;
  }

  return undef;
}

sub dispatch_uri
{
  my $uri   = $_[0]->server->requested_uri;
  my $regex = $_[0]->root_uri_regex;
  $uri =~ s/$regex//;

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
    $self->{'pages'} = {};
    $self->add_pages(@_);
  }

  return wantarray ? values(%{$self->{'pages'} ||= {}}) : ($self->{'pages'} ||= {});
}

sub add_pages
{
  my($self) = shift;

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

  my $page_class = $self->page_class;

  my $pages = $self->{'pages'} ||= {};

  while(my($name, $value) = each(%$args))
  {
    if(exists $pages->{$name})
    {
      croak "A page named '$name' already exists.  Use $self->page($name => ...) to replace";
    }

    if(ref $value eq 'HASH')
    {
      $pages->{$name} = $page_class->new(%$value, name => $name, app => $self);
    }
    elsif(ref $value && $value->isa($page_class))
    {
      $value->name($name);
      $value->app($self);
      $pages->{$name} = $value;
    }
    else
    {
      croak(ref($self), "::pages() - invalid page argument value: '$value'");
    }
  }
}

sub comps
{
  my($self) = shift;

  if(@_)
  {
    $self->{'comps'} = {};
    $self->add_comps(@_);
  }

  return wantarray ? values(%{$self->{'comps'} ||= {}}) : ($self->{'comps'} ||= {});
}

sub add_comps
{
  my($self) = shift;

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

  my $comp_class = $self->comp_class;

  my $comps = $self->{'comps'} ||= {};

  while(my($name, $value) = each(%$args))
  {
    if(exists $comps->{$name})
    {
      croak "A comp named '$name' already exists.  Use $self->comp($name => ...) to replace";
    }

    if(ref $value eq 'HASH')
    {
      $comps->{$name} = $comp_class->new(name => $name, app => $self, %$value);
    }
    elsif(ref $value eq 'ARRAY')
    {
      $comps->{$name} = $comp_class->new(name => $name, app => $self, @$value);
    }
    elsif(ref $value && $value->isa($comp_class))
    {
      $value->name($name);
      $value->app($self);
      $comps->{$name} = $value;
    }
    else
    {
      croak(ref($self), "::comps() - invalid comp argument value: '$value'");
    }
  }
}

sub forms
{
  my($self) = shift;

  if(@_)
  {
    $self->{'forms'} = {};
    $self->add_forms(@_);
  }

  return wantarray ? values(%{$self->{'forms'} ||= {}}) : ($self->{'forms'} ||= {});
}

sub add_forms
{
  my($self) = shift;

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

  my $form_class = $self->form_class;

  my $forms = $self->{'forms'} ||= {};

  while(my($name, $value) = each(%$args))
  {
    if(exists $forms->{$name})
    {
      croak "A form named '$name' already exists.  Use $self->form($name => ...) to replace";
    }

    if(ref $value eq 'HASH')
    {
      $value->{'action_method'} = $self->default_form_action_method
        unless(exists $value->{'action_method'});

      $forms->{$name} = $form_class->new(name => $name, app => $self, %$value);
    }
    elsif(ref $value eq 'ARRAY')
    {
      $forms->{$name} = $form_class->new(name => $name, app => $self, @$value);
    }
    elsif(ref $value && $value->isa($form_class))
    {
      $value->name($name);
      $value->app($self);
      $forms->{$name} = $value;
    }
    else
    {
      croak(ref($self), "::forms() - invalid form argument value: '$value'");
    }
  }
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

# sub stash
# {
#   my($self) = shift;
#   
#   my %args = (@_ == 2) ? (name => $_[0], value => $_[1]) :
#              (@_ == 1) ? (name => $_[0]) : @_;
# 
#   my $session;
#   
#   my $domain = $args{'domain'};
# 
#   if(ref $self)
#   {
#     $domain ||= ref $self;
#     $session = $self->user->session or croak "Could not get user's session";
#   }
#   else
#   {
#     $domain ||= $self;
#     $session = $self->website->session;
#   }
# 
#   die "Missing name argument"  unless($args{'name'});
# 
#   if(@_ == 1)
#   {
#     return $session->stash(domain => $domain, name => $args{'name'});
#   }
#   elsif(@_)
#   {
#     die "Missing value argument"  unless(exists $args{'value'});
#     return $session->stash(domain => $domain, name => $args{'name'}, value => $args{'value'});
#   }
# 
#   return undef;
# }

# This is both a class method and an object method

sub clear_stash
{
  my($self) = shift;

  my($session, $domain);

#   if($domain = ref $self)
#   {
#     $session = $self->user->session or croak "Could not get user's session";
#   }
#   else
#   {
#     $domain = $self;
#     $session = Rose::WebSite->user->session;
#   }
#   
#   @_ = (name => $_[0])  if(@_ == 1);
# 
#   $session->clear_stash(domain => $domain, @_);
}

# XXX: This is undocumented for now...
#
# =item B<import_methods NAME1 [, NAME2, ...]>
# 
# Import methods from the named class (the invocant) into the current class.
# This works by searching the class hierarchy, starting from the invocant class,
# and using a breadth-first search.  When an existing method with the requested
# NAME is found, it is aliased into the current (calling) package.  If a method
# of the desired name is not found, a fatal error is thrown.
# 
# This is a somewhat evil hack that i used internally to get around some
# inconvenient consequences of multiple inheritence and its interaction with
# Perl's default left-most depth-first method dispatch.
# 
# This method is an implementation detail and is not part of the public "user"
# API. It is described here for the benefit of those who are subclassing
# C<Rose::HTML::Object> and who also may find themselves in a bit of a multiple
# inheritence bind.
# 
# Example:
# 
#     package MyTag;
# 
#     use SomeTag;
#     our @ISA = qw(SomeTag);
# 
#     use MyOtherTag;
# 
#     # Do a bredth-first search, starting in the class MyOtherTag,
#     # for methods named 'foo' and 'bar', and alias them into
#     # this package (MyTag)
#     MyOtherTag->import_methods('foo', 'bar');

# If method dispatch was breadth-first, I probably wouldn't need this...
sub import_methods
{
  my($this_class) = shift;

  my $target_class = (caller)[0];

  my(@search_classes, @parents);

  @parents = ($this_class);

  while(my $class = shift(@parents))
  {
    push(@search_classes, $class);

    no strict 'refs';
    foreach my $subclass (@{$class . '::ISA'})
    {
      push(@parents, $subclass);
    }
  }

  my %methods;

  foreach my $arg (@_)
  {
    if(ref $arg eq 'HASH')
    {
      $methods{$_} = $arg->{$_}  for(keys %$arg);
    }
    else
    {
      $methods{$arg} = $arg;
    }
  }

  METHOD: while(my($method, $import_as) = each(%methods))
  {
    no strict 'refs';
    foreach my $class (@search_classes)
    {
      if(defined &{$class . '::' . $method})
      {
        #print STDERR "${target_class}::$import_as = ${class}::$method\n";
        *{$target_class . '::' . $import_as} = \&{$class . '::' . $method};
        next METHOD;
      }
    }

    Carp::croak "Could not find method '$method' in any subclass of $this_class";
  }
}

1;
