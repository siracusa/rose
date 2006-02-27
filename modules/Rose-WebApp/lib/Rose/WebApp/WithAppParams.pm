package Rose::WebApp::WithAppParams;

use strict;

use Rose::Test::WebApp;
our @ISA = qw(Rose::Test::WebApp);

__PACKAGE__->register_subclass;

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(

  'scalar --get_set_init' =>
  [
    'app_param_prefix',
  ],

  hash =>
  [
    app_params => { interface => 'get_set' },
  ],
);

sub feature_name { 'appparams' }

sub init_app_param_prefix { 'APP_' }

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

    my $prefix = $self->app_param_prefix;
    my $length = length($prefix);
   # my $prefix_re = qr{^@{[ $self->app_param_prefix ]}(.+)};

    foreach my $param (keys %{$self->{'params'}})
    {
      #$Debug && warn "Param $param = $value\n";
      if(index($param, $prefix) == 0)
      {
        #$Debug && warn "App param $1 = $value\n";
        $self->app_param(substr($param, $length) => $self->{'params'}{$param});
        delete $self->{'params'}{$param};
      }
      elsif($param =~ /^(.+)\.[xy]$/)
      {
        # Handle image map clicks: foo.x and foo.y -> foo
        $self->{'params'}{$1} = delete $self->{'params'}{$param};
      }
    }
  }

  return (wantarray) ? %{$self->{'params'}} : $self->{'params'};
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

1;
