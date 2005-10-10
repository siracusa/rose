package Rose::HTML::Form::Field::Option;

use strict;

use Rose::HTML::Util();

use Rose::HTML::Form::Field::WithContents;
use Rose::HTML::Form::Field::OnOff::Selectable;
our @ISA = qw(Rose::HTML::Form::Field::OnOff::Selectable Rose::HTML::Form::Field::WithContents);

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::WithContents->import_methods(
{
  html_tag  => '_html_tag',
  xhtml_tag => '_xhtml_tag',  
});

our $VERSION = '0.011';

__PACKAGE__->add_valid_html_attrs
(
  'label',
  'selected',
);

__PACKAGE__->add_boolean_html_attrs
(
  'selected',
);

__PACKAGE__->delete_valid_html_attrs(qw(name type checked));
__PACKAGE__->delete_required_html_attr('type');

sub html_element  { 'option' }
sub xhtml_element { 'option' }

sub html_field
{
  my($self) = shift;
  $self->contents(Rose::HTML::Util::escape_html($self->label));
  $self->html_attr(selected => $self->selected);
  return $self->_html_tag(@_);
}

sub xhtml_field
{
  my($self) = shift; 
  $self->contents(Rose::HTML::Util::escape_html($self->label));
  $self->html_attr(selected => $self->selected);
  return $self->_xhtml_tag(@_);
}

sub short_label { shift->html_attr('label', @_) }

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::Option - Object representation of the
"option" HTML tag.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::Option->new(
        value => 'apple',
        label => 'Apple');

    $field->selected(1);

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Option> is an object representation of a single
option in a pop-up menu or select box in an HTML form.

This class inherits from, and follows the conventions of,
L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not
be documented a second time here.  See the L<Rose::HTML::Form::Field>
documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accept
    accesskey
    alt
    checked
    class
    dir
    disabled
    id
    ismap
    label
    lang
    maxlength
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
    selected
    size
    src
    style
    tabindex
    title
    type
    usemap
    value
    xml:lang

Required attributes:

    value

Boolean attributes:

    checked
    disabled
    ismap
    readonly
    selected

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::Option> object based on PARAMS,
where PARAMS are name/value pairs.  Any object method is a valid parameter
name.

=back

=head1 OBJECT METHODS

=over 4

=item B<short_label [TEXT]>

Get or set the value of the "label" HTML attribute.  When present, user agents
are supposed to use this value instead of the contents of the option tag as the
label for the option.  Example:

    $field =
      Rose::HTML::Form::Field::Option->new(
        value => 'apple',
        label => 'Shiny Apple');

    print $field->html;

    # The HTML:
    #
    #   <option value="apple">Shiny Apple</option>
    #
    # Label shown in web browser: "Shiny Apple"

    $field->short_label("Apple");
    print $field->html;

    # The HTML:
    #
    #   <option label="Apple" value="apple">Shiny Apple</option>
    #
    # Label shown in web browser: "Apple"

(Hey, don't look at me, I didn't write the HTML specs...)

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
