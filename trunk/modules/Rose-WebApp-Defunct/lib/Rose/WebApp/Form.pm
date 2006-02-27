package Rose::WebApp::Form;

use strict;

use Carp();

use Scalar::Util();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    'name',
    'html_form_class',
    'view_path',
    'action_uri',
    'action_method',
    'preparer',
    'prepare_pre_hook',
    'prepare_post_hook',
  ],

  'boolean' => 
  [
    'secure',
    'prepared',
    'should_prepare'    => { default => 1 },
    'should_validate'   => { default => 1 },
    'should_init'       => { default => 1 },
    'clear_on_init'     => { default => 0 },
    'reset_on_init'     => { default => 1 },
    'build_on_init'     => { default => 1 },
    '_build_on_prepare' => { default => 0 },
  ],
);

*class = \&html_form_class;

sub field { shift->html_form->field(@_) }

sub app
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'app'} = shift)  if(@_);
  return $self->{'app'};
}

sub build_on_prepare
{
  my($self) = shift;

  if(@_)
  {
    if($self->_build_on_prepare(@_))
    {
      $self->build_on_init(0);
    }
  }

  return $self->_build_on_prepare;
}

# sub action_uri
# {
#   my($self) = shift;
#   $self->{'action_uri'} = shift  if(@_);
#   return (ref $self->{'action_uri'} eq 'CODE') ? 
#     $self->{'action_uri'}->($self, $self->app) : $self->{'action_uri'};
# }

sub html_form
{
  my($self) = shift;

  return $self->{'html_form'} = shift  if(@_);

  return $self->{'html_form'}  if($self->{'html_form'});

  if(my $class = $self->html_form_class)
  {
    my $form = 
      $class->new(action => scalar $self->action_uri,
                  method => scalar($self->action_method) || 
                            $self->app->default_form_action_method,
                  build_on_init => $self->build_on_init);

    if($form->can('app'))
    {
      $form->app($self->app);
    }

    return $self->{'html_form'} = $form;
  } 

  return undef;
}

sub reset
{
  my($self) = shift;

  if(my $html_form = $self->html_form)
  {
    $html_form->reset;
  }

  $self->prepared(0);
}

sub error { shift->html_form->error(@_) }

sub is_prepared { shift->prepared ? 1 : 0 }

sub DESTROY { }

our $AUTOLOAD;

sub AUTOLOAD
{
  my($self) = $_[0];

  my $class = ref($self) or Carp::croak "$self is not an object";

  my $name = $AUTOLOAD;
  $name =~ s/.*://;

  if(my $html_form = $self->html_form)
  {
    if($html_form->can($name))
    {
      no strict 'refs';
      *$AUTOLOAD = sub { shift->html_form->$name(@_) };
      #${$class . '::__AUTOLOADED'}{$name} = 1;
      goto &$AUTOLOAD;
    }
    else
    {
      Carp::confess 
        qq(Can't locate object method "$name" via package $class, and did ),
        qq(not forward to the html_form() ), ref($html_form), 
        qq(because it doesn't have a method by that name either.);
    }
  }

  Carp::confess
    "Cannot forward the method $name() to the html_form() object ",
    "because none is set.";
}

1;
