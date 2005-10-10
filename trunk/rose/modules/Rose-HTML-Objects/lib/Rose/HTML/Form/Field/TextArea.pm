package Rose::HTML::Form::Field::TextArea;

use strict;

use Rose::HTML::Form::Field::WithContents;
our @ISA = qw(Rose::HTML::Form::Field::WithContents);

our $VERSION = '0.012';

__PACKAGE__->add_valid_html_attrs
(
  'rows',        # NUMBER         #REQUIRED
  'cols',        # NUMBER         #REQUIRED
  'disabled',    # (disabled)     #IMPLIED  -- unavailable in this context --
  'readonly',    # (readonly)     #IMPLIED
  'onselect',    # %Script;       #IMPLIED  -- some text was selected --
  'onchange',    # %Script;       #IMPLIED  -- the element value was changed --
);

__PACKAGE__->add_required_html_attrs(
{
  rows  => 6,
  cols  => 50,
});

__PACKAGE__->add_boolean_html_attrs
(
  'disabled',
  'readonly',
);

sub html_element  { 'textarea' }
sub xhtml_element { 'textarea' }

sub value { shift->contents(@_) }

sub escape_html_contents { 1 }

sub contents
{
  my($self) = shift;
  return $self->input_value(@_)  if(@_);
  return $self->output_value;
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::TextArea - Object representation of a multi-line text field in an HTML form.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::TextArea->new(
        label => 'Comments', 
        name  => 'comments',
        rows  => 2,
        cols  => 50);

    $comments = $field->internal_value;

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::TextArea> is an object representation of a multi-line text field in an HTML form.

This class inherits from, and follows the conventions of, L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Form::Field> documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accesskey
    class
    cols
    dir
    disabled
    id
    lang
    name
    onblur
    onchange
    onclick
    ondblclick
    onfocus
    onkeydown
    onkeypress
    onkeyup
    onmousedown
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    onselect
    readonly
    rows
    style
    tabindex
    title
    value
    xml:lang

Required attributes (default values in parentheses):

    cols (50)
    rows (6)

Boolean attributes:

    checked
    disabled
    readonly

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::TextArea> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<contents [TEXT]>

Get or set the contents of the text area.  If a TEXT argument is present, it is passed to L<input_value()|Rose::HTML::Form::Field/input_value> and the return value of that method call is then returned. Otherwise, L<output_value()|Rose::HTML::Form::Field/output_value> is called with no arguments.

=item B<value [TEXT]>

Simply calls L<contents()|/contents>, passing all arguments.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
