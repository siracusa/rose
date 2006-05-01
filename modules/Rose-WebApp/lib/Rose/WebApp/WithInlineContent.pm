package Rose::WebApp::WithInlineContent;

use strict;

use Carp;

use File::Path;
use Path::Class();
use Path::Class::File();
use Path::Class::Dir();

use Rose::WebApp::InlineContent::Util qw(extract_inline_content create_inline_content);

use Rose::WebApp::Feature;
our @ISA = qw(Rose::WebApp::Feature);

our $VERSION = '0.01';

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => '_inline_content_hash',
);

__PACKAGE__->register_subclass;

sub feature_setup
{
  my($class, $using_class) = @_;
  
  my %inline_content;

  extract_inline_content(class => $using_class, dest => \%inline_content);
  
  $class->_inline_content_hash(\%inline_content);
}

sub inline_content
{
  my($self) = shift;
  
  if(my $ref = $self->inline_content_ref(@_))
  {
    return $$ref;
  }

  return undef;
}

sub inline_content_ref
{
  my($self, $path) = (shift, shift);
  
  my $class = ref($self) || $self;

  my $hash = $class->_inline_content_hash;

  if(@_)
  {
    $hash->{$path} = shift;
    return $hash->{$path}{'contents'};
  }

  return undef  unless($hash->{$path});

  return \$hash->{$path}{'contents'};
}

sub inline_content_exists
{
  my($self, $path) = (shift, shift);
  
  my $class = ref($self) || $self;
  my $hash = $class->_inline_content_hash;
  return $hash->{$path} ? 1 : 0;
}

1;
