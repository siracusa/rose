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

__PACKAGE__->register_feature;

sub feature_name { 'inline-content' }

sub feature_setup
{
  my($class, $for_class) = @_;

  no strict 'refs';

  __traverse_class_hierarchy($for_class, sub 
  {
    $for_class->load_inline_content_from_class($_[0]);
  });
}

sub __traverse_class_hierarchy
{
  my($class, $code) = @_;

  $code->($class);

  no strict 'refs';
  foreach my $isa_class (@{"${class}::ISA"})
  {
    next  unless($isa_class->isa('Rose::WebApp'));
    __traverse_class_hierarchy($isa_class, $code);
  }
}

sub load_inline_content_from_class
{
  my($self_or_class, $from_class) = @_;

  my $class = ref $self_or_class || $self_or_class;
  my $hash  = $class->_inline_content_hash || {};  
#print STDERR "EXTRACTING INLINE CONTENT FROM $from_class\n";
  extract_inline_content(class => $from_class, dest => $hash);

  $class->_inline_content_hash($hash);
}

sub delete_inline_content
{
  my($self_or_class) = shift;
  my $class = ref $self_or_class || $self_or_class;
  $class->_inline_content_hash({});
}

sub default_inline_content_group { Rose::WebApp::InlineContent::Util->default_group }
sub inline_content_search_groups { [ 'htdocs', 'mason-comps' ] }

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
  my($self) = shift;

  if(my $info = $self->inline_content_info(@_))
  {
    return \$info->{'content'};
  }

  return undef;
}

sub inline_content_info
{
  my($self) = shift;

  my %args = @_ == 1 ? (path => $_[0]) : @_;

  my $path   = $args{'path'} or croak "Missing path argument";
  my $groups = $args{'groups'} || 
    [ $args{'group'} || @{$self->inline_content_search_groups} ];
#print STDERR "GET INLINE CONTENT INFO: @$groups - $path\n";
  my $class = ref($self) || $self;

  my $hash = $class->_inline_content_hash;
#use Data::Dumper;
#print STDERR "INLINE CONTENT HASH: ", Dumper($hash);
  if(my $content = $args{'content'})
  {
    my $group = $args{'group'} || $self->default_group;

    return $hash->{$group}{$path} = 
    {
      group    => $group,
      content  => $content, 
      modified => time 
    };
  }

  foreach my $group (@$groups)
  {
    next  unless($hash->{$group}{$path});
#print STDERR "FOUND INLINE CONTENT: $path\n";
    return $hash->{$group}{$path};
  }

  return undef;
}

sub inline_content_exists
{
  my($self, $path) = (shift, shift);

  my $class = ref($self) || $self;
  my $hash = $class->_inline_content_hash;
  return $hash->{$path} ? 1 : 0;
}

1;
