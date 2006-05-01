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
  
  my %inline_content;
print STDERR "EXTRACTING INLINE CONTENT FOR $for_class\n";
  extract_inline_content(class => $for_class, dest => \%inline_content);
  
  $class->_inline_content_hash(\%inline_content);
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
print STDERR "GET INLINE CONTENT INFO: @$groups - $path\n";
  my $class = ref($self) || $self;

  my $hash = $class->_inline_content_hash;
use Data::Dumper;
print STDERR "INLINE CONTENT HASH: ", Dumper($hash);
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
print STDERR "FOUND INLINE CONTENT: $path\n";
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
