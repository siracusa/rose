package Rose::HTML::Form::Field::Hidden;

use strict;

use Rose::HTML::Form::Field::Input;
our @ISA = qw(Rose::HTML::Form::Field::Input);

our $VERSION = '0.011';

__PACKAGE__->delete_valid_html_attrs(qw(disabled ismap usemap alt src tabindex
checked maxlength onblur onchange onclick ondblclick onfocus onkeydown
onkeypress onkeyup onmousedown onmousemove onmouseout onmouseover onmouseup
onselect readonly size title accesskey));

__PACKAGE__->add_required_html_attrs('value');
__PACKAGE__->required_html_attr_value(type => 'hidden');

sub hidden_fields       { (wantarray) ? shift : [ shift ] }
sub html_hidden_fields  { (wantarray) ? shift->html_field : [ shift->html_field ] }
sub xhtml_hidden_fields { (wantarray) ? shift->xhtml_field : [ shift->xhtml_field ] }

sub clear    {   }
sub error    {   }
sub validate { 1 }

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::Hidden - Object representation of a hidden field in an HTML form.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::Hidden->new(
        name  => 'code',  
        value => '1234');

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Hidden> is an object representation of a hidden field in an HTML form.

This class inherits from, and follows the conventions of, L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Form::Field> documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accept
    class
    dir
    id
    lang
    name
    style
    type
    value
    xml:lang

Required attributes (default values in parentheses):

    type (hidden)
    value

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::Hidden> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
