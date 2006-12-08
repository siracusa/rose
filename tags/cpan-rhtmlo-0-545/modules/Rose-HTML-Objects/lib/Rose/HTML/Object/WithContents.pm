package Rose::HTML::Object::WithContents;

use strict;

use Carp();

use Rose::HTML::Util();

use Rose::HTML::Object;
our @ISA = qw(Rose::HTML::Object);

our $VERSION = '0.011';

use Rose::Object::MakeMethods::Generic
(
  scalar  => 'contents',
  boolean => 'escape_html_contents',
);

sub start_html 
{
  my($self) = shift; 
  return '<' . $self->html_element . $self->html_attrs_string . '>';
}

sub start_xhtml 
{
  my($self) = shift; 
  return '<' . $self->xhtml_element . $self->xhtml_attrs_string . '>';
}

sub end_html 
{
  my($self) = shift; 
  return '</' . $self->html_element . '>';
}

sub end_xhtml 
{
  my($self) = shift; 
  return '</' . $self->xhtml_element . '>';
}

sub html_tag
{
  my($self) = shift;
  my(%args) = @_;

  my $element = ref($self)->html_element;

  my $contents = exists $args{'contents'} ?  $args{'contents'} : $self->contents;
  $contents = ''  unless(defined $contents);

  no warnings;
  return "<$element" . $self->html_attrs_string . '>' .
         ($self->escape_html_contents ? Rose::HTML::Util::escape_html($contents) : $contents) . 
         "</$element>";
}

sub xhtml_tag
{
  my($self) = shift;
  my(%args) = @_;

  my $element = ref($self)->xhtml_element;

  my $contents = exists $args{'contents'} ?  $args{'contents'} : $self->contents;
  $contents = ''  unless(defined $contents);

  no warnings;
  return "<$element" . $self->xhtml_attrs_string . '>' .
         ($self->escape_html_contents ? Rose::HTML::Util::escape_html($contents) : $contents) . 
         "</$element>";
}

1;
