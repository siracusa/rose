package Rose::BuildConf::Class;

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
    qw(preamble skip_if)
  ],
);

sub init
{
  my($self) = shift;

  @_ = (name => $_[0])  if(@_ == 1);

  $self->{'questions'} = [];

  $self->SUPER::init(@_);  
}

sub should_skip
{
  my($self) = shift;

  my $code = $self->{'skip_if'};

  return 0  unless($code);
  return ($code->()) ? 1 : 0;
}

sub name
{ 
  $_[0]->{'name'} = $_[1]  if(@_ > 1);
  return $_[0]->{'name'}
}

*class = \&name;

sub questions
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      $self->{'questions'} = shift;
    }
    else
    {
      $self->{'questions'} = [ @_ ];
    }
  }

  return wantarray ? @{$self->{'questions'}} : $self->{'questions'};
}

sub num_questions
{
  return scalar @{$_[0]->{'questions'}};
}

sub add_question
{
  my($self, $question) = @_;

  croak "No question to add"  unless(defined $question);
  croak "Question is not a Rose::BuildConf::Question object"
    unless(ref $question && $question->isa('Rose::BuildConf::Question'));

  my $class = $question->class;

  if(defined $class && $class ne $self->class)
  {
    croak "Question class '$class' conflicts with class object '@{[$self->class]}'";
  }
  else
  {
    $question->class($self);
  }

  push(@{$self->{'questions'}}, $question);
}

sub local_conf_value
{
  my($self, $param) = @_;

  croak "Missing param argument"  unless(defined $param);

  my $class = $self->name 
    or croak "Cannot get local_conf_value() without class name";

  return $class->local_conf_value($param);
}

sub conf_param_exists
{
  my($self, $param) = @_;

  my $class = $self->name 
    or croak "Cannot check if conf_param_exists() without class name";

  croak "Cannot check if conf_param_exists() without param name"
    unless(defined $param);

  my($hash, $key) = _conf_hash_and_key($class, $param);

  return exists $hash->{$key} ? 1 : 0;

  #return $class->param_exists($param);
}

sub conf_hash
{
  my($self) = shift;

  my $class = $self->name 
    or croak "Cannot get conf_hash() without class name";

  return $class->conf_hash;
}

sub conf_value
{
  my($self)  = shift;
  my($param) = shift;

  my $class = $self->name 
    or croak "Cannot get conf_value() without class name";

  my($hash, $key) = _conf_hash_and_key($class, $param);

  return $hash->{$key} = shift  if(@_);
  return $hash->{$key};

  #return $class->param(@_);
}

sub _conf_hash_and_key
{
  my($class, $key) = @_;

  if($key =~ m/^(?:[^\\:]+|\\.)+:/)
  {
    if($key =~ /^(?:[^\\:]+|\\.)+:$/)
    {
      Carp::croak qq($class - Invalid hash sub-key access: "$key" - missing key name after final ':');
    }

    my @parts;
    my $hash = $class->conf_hash;
    my $prev_hash;

    while($key =~ m/\G((?:[^\\: \t]+|\\.)+)(?::|$)/g)
    {
      $prev_hash = $hash;
      my $key = $1;
      $key =~ s{\\(.)}{$1}g;
      $hash = $hash->{$key} ||= {};
      push(@parts, $key);
    }

    $Debug && warn "Get conf value for \$${class}::CONF{", join('}{', @parts), "}\n";

    return $prev_hash, $parts[-1];
  }

  $key =~ s{\\:}{:}g;
  return $class->conf_hash, $key;
}

1;
