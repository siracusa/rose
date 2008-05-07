package Rose::HTML::Object::WithContents;

use strict;

use Carp();

use Rose::HTML::Util();

use Rose::HTML::Object;
our @ISA = qw(Rose::HTML::Object);

our $VERSION = '0.549';

use Rose::Object::MakeMethods::Generic
(
  scalar  => 'contents',
  boolean => 'escape_html_contents',
  'scalar --get_set_init' => 'apply_error_class',
);

sub init_apply_error_class { 1 }

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

  my $element = $self->html_element;

  my $contents = exists $args{'contents'} ?  $args{'contents'} : $self->contents;
  $contents = ''  unless(defined $contents);

  $contents =
    (UNIVERSAL::isa($contents, 'Rose::HTML::Object')) ? $contents->html_tag : 
    ($self->escape_html_contents ? Rose::HTML::Util::escape_html($contents) : $contents);

  if($self->apply_error_class && defined $self->error)
  {
    my $class = $self->html_attr('class');
    $self->html_attr(class => $class ? "$class error" : 'error');

    no warnings;
    my $html =
      "<$element" . $self->html_attrs_string . ">$contents</$element>";

    $self->html_attr(class => $class);
    return $html;
  }

  no warnings;
  return "<$element" . $self->html_attrs_string . ">$contents</$element>";
}

sub xhtml_tag
{
  my($self) = shift;
  my(%args) = @_;

  my $element = $self->xhtml_element;

  my $contents = exists $args{'contents'} ?  $args{'contents'} : $self->contents;
  $contents = ''  unless(defined $contents);

  $contents =
    (UNIVERSAL::isa($contents, 'Rose::HTML::Object')) ? $contents->xhtml_tag : 
    ($self->escape_html_contents ? Rose::HTML::Util::escape_html($contents) : $contents);

  if($self->apply_error_class && defined $self->error)
  {
    my $class = $self->html_attr('class');
    $self->html_attr(class => $class ? "$class error" : 'error');

    no warnings;
    my $xhtml =
      "<$element" . $self->xhtml_attrs_string . ">$contents</$element>";

    $self->html_attr(class => $class);
    return $xhtml;
  }

  no warnings;
  return "<$element" . $self->xhtml_attrs_string . ">$contents</$element>";
}

1;
