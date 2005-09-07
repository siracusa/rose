package Rose::BuildConf::Question;

use strict;

use Carp;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    qw(class conf_param question prompt default validate pre_action 
       post_action post_set_action input_filter output_filter skip_if error)
  ],
);

sub class_name
{
  my($self) = shift;

  my $class = $self->class or return;

  return $class->name;
}

sub local_conf_value
{
  my($self) = shift;

  my $class = $self->class 
    or croak "Cannot get local_conf_value() without question class";

  return $class->local_conf_value($self->conf_param);
}

sub conf_param_exists
{
  my($self) = shift;

  my $class = $self->class 
    or croak "Cannot get conf_param_exists() without question class";

  return $class->conf_param_exists($self->conf_param);
}

sub conf_value
{
  my($self) = shift;

  my $class = $self->class 
    or croak "Cannot get conf_value() without question class";

  return $class->conf_value($self->conf_param, @_);
}

sub should_skip
{
  my($self) = shift;

  my $code = $self->{'skip_if'};

  return 0  unless($code);
  return ($code->()) ? 1 : 0;
}

sub filter
{
  my($self) = shift;

  if(@_)
  {
    my $filter = shift;
    $self->{'input_filter'}  = $filter;
    $self->{'output_filter'} = $filter;
  }

  my $input_filter = $self->{'input_filter'};

  if(ref $input_filter && $input_filter eq $self->output_filter)
  {
    return $input_filter;
  }

  return;
}

1;
