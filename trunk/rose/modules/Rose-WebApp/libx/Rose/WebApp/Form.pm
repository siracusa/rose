package Rose::WebApp::Form;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    'name',
    'form_class',
    'view_path',
    'action_uri',
    'action_method',
  ],

  'boolean' => 
  [
    'prepared',
    'should_prepare'       => { default => 1 }
    'should_validate'      => { default => 1 }
    'should_init'          => { default => 1 }
    'should_clear_on_init' => { default => 1 }
  ],
);

sub html_form
{
  my($self) = shift;

  return $self->{'html_form'} = shift  if(@_);

  return $self->{'html_form'}  if($self->{'html_form'});

  if(my $class = $self->{'form_class'})
  {
    my $action_uri = $self->action_uri;

    $action_uri = $action_uri->()  if(ref $action_uri eq 'CODE');

    return $self->{'html_form'} = 
      $class->new(action => $action_uri,
                  method => $self->action_method || 'post');
  }

  return undef;
}

sub reset
{
  $_[0]->html_form->reset;
  $_[0]->prepared(0);
}

sub error { shift->html_form->error(@_) }

sub is_prepared { shift->prepared ? 1 : 0 }

1;
