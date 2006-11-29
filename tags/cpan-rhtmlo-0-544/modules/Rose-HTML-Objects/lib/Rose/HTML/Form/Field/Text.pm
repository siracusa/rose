package Rose::HTML::Form::Field::Text;

use strict;

use Rose::HTML::Object::Errors qw(:string);

use Rose::HTML::Form::Field::Input;
our @ISA = qw(Rose::HTML::Form::Field::Input);

our $VERSION = '0.544';

__PACKAGE__->delete_valid_html_attrs(qw(ismap usemap alt src));

__PACKAGE__->add_required_html_attrs(
{
  type  => 'text',
  name  => '',
  size  => 15,
  value => '',
});

sub html_field
{
  my($self) = shift;
  $self->html_attr(value => $self->output_value);
  return $self->SUPER::html_field(@_);
}

sub xhtml_field
{
  my($self) = shift;
  $self->html_attr(value => $self->output_value);
  return $self->SUPER::xhtml_field(@_);
}

sub validate
{
  my($self) = shift;

  my $ok = $self->SUPER::validate(@_);
  return $ok  unless($ok);

  my $value = $self->input_value;
  return 1  unless(defined $value && length $value);

  my $maxlength = $self->maxlength;

  my $name = sub { $self->label || $self->name };

  if(defined $maxlength && length($value) > $maxlength)
  {
    $self->add_error_id(STRING_OVERFLOW, { label => $name, value => $maxlength });
    return 0;
  }

  return 1;
}

if(__PACKAGE__->localizer->auto_load_messages)
{
  __PACKAGE__->localizer->load_all_messages;
}

1;

__DATA__

[% LOCALE en %]

STRING_OVERFLOW = "[label] must not exceed [maxlength] characters."

__END__

=head1 NAME

Rose::HTML::Form::Field::Text - Object representation of a text field in an HTML form.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::Text->new(
        label     => 'Your Age', 
        name      => 'age',
        size      => 2,
        maxlength => 3);

    $age = $field->internal_value;

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Text> is an object representation of a text field in an HTML form.

This class inherits from, and follows the conventions of, L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Form::Field> documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accept
    accesskey
    checked
    class
    dir
    disabled
    id
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
    size
    style
    tabindex
    title
    type
    value
    xml:lang

Required attributes (default values in parentheses):

    name
    size  (15)
    type  (text)
    value

Boolean attributes:

    checked
    disabled
    readonly

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::Text> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
