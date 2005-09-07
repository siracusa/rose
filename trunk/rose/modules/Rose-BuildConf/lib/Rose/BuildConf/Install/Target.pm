package Rose::BuildConf::Install::Target;

use strict;

use File::Basename;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  scalar => 
  [
    qw(name tag preamble source destination mode filter
       skip reinstall force)
  ],

  boolean => [ qw(recursive enabled) ],
);

sub init
{
  my($self) = shift;

  $self->skip(\&_default_skip);
  $self->mode('copy');
  $self->recursive(1);
  $self->enabled(1);

  $self->SUPER::init(@_);
}

sub is_enabled  { ($_[0]->{'enabled'}) ? 1 : 0 }
sub is_disabled { ($_[0]->{'enabled'}) ? 0 : 1 }

sub disable { $_[0]->{'enabled'} = 0 }
sub enable  { $_[0]->{'enabled'} = 1 }

sub should_install
{
  my($self, $source_path) = @_;

  my $install = 1;

  local $_ = $source_path;

  if(ref $self->filter eq 'CODE')
  {
    $install = $self->filter->($self, $source_path);
  }

  return $install;
}

sub _default_skip
{
  my($self, $source_path) = @_;

  my $file = basename($source_path);

  return 1  if($file =~ m/^(?:\.DS_Store|\.p4ignore|\._.+|.+\.tmpl|.+~)$/);
  return 0;
}

sub should_skip
{
  my($self, $source_path) = @_;

  my $skip;

  local $_ = $source_path;

  if(ref $self->skip eq 'CODE')
  {
    $skip = $self->skip->($self, $source_path);
  }

  return $skip;
}

1;
