package Rose::HTML::Form::Field::PopUpMenu;

use strict;

use Rose::HTML::Form::Field::SelectBox;
our @ISA = qw(Rose::HTML::Form::Field::SelectBox);

our $VERSION = '0.544';

__PACKAGE__->required_html_attr_value(size => 1);
__PACKAGE__->delete_valid_html_attr('multiple');

sub multiple { 0 }

sub internal_value
{
  my($self) = shift;
  my $values = $self->SUPER::internal_value(@_);
  return $values->[0];
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::PopUpMenu - Object representation of a pop-up menu in an HTML form.

=head1 SYNOPSIS

    $field = Rose::HTML::Form::Field::PopUpMenu->new(name => 'fruits');

    $field->options(apple  => 'Apple',
                    orange => 'Orange',
                    grape  => 'Grape');

    print $field->value_label('apple'); # 'Apple'

    $field->input_value('orange');

    print $field->internal_value; # 'orange'

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::PopUpMenu> is an object representation of a pop-up menu field in an HTML form.

This class inherits from, and follows the conventions of, L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Form::Field> documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accesskey
    class
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
    size
    style
    tabindex
    title
    value
    xml:lang

Required attributes:

    name
    size

Boolean attributes:

    disabled

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::PopUpMenu> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_option OPTION>

Convenience alias for L<add_options()|/add_options>.

=item B<add_options OPTIONS>

Adds options to the pop-up menu.  OPTIONS may be a reference to a hash of value/label pairs, a reference to an array of values, or a list of objects that are of, or inherit from, the classes L<Rose::HTML::Form::Field::Option> or L<Rose::HTML::Form::Field::OptionGroup>. Passing an odd number of items in the value/label argument list causes a fatal error. Options passed as a hash reference are sorted by value according to the default behavior of Perl's built-in L<sort()|perlfunc/sort> function.  Options are added to the end of the existing list of options.

=item B<choices [OPTIONS]>

This is an alias for the L<options|/options> method.

=item B<has_value VALUE>

Returns true if VALUE is selected in the pop-up menu, false otherwise.

=item B<labels [LABELS]>

Get or set the labels for all values.  If LABELS is a reference to a hash or a list of value/label pairs, then LABELS replaces all existing labels.  Passing an odd number of items in the list version of LABELS causes a fatal error.

Returns a hash of value/label pairs in list context, or a reference to a hash in scalar context.

=item B<option VALUE>

Returns the first option (according to the order that they are returned from L<options()|/options>) whose "value" HTML attribute is VALUE, or undef if no such option exists.

=item B<options OPTIONS>

Get or set the full list of options in the pop-up menu.  OPTIONS may be a reference to a hash of value/label pairs, an ordered list of value/label pairs, a reference to an array of values, or a list of objects that are of, or inherit from, the classes L<Rose::HTML::Form::Field::Option> or L<Rose::HTML::Form::Field::OptionGroup>. Passing an odd number of items in the value/label argument list causes a fatal error. Options passed as a hash reference are sorted by value according to the default behavior of Perl's built-in L<sort()|perlfunc/sort> function.

To set an ordered list of option values along with labels in the constructor, use both the L<options()|/options> and L<labels()|/labels> methods in the correct order. Example:

    $field = 
      Rose::HTML::Form::Field::PopUpMenu->new(
        name    => 'fruits',
        options => [ 'apple', 'pear' ],
        labels  => { apple => 'Apple', pear => 'Pear' });

Remember that methods are called in the order that they appear in the constructor arguments (see the L<Rose::Object> documentation), so L<options()|/options> will be called before L<labels()|/labels> in the example above.  This is important; it will not work in the opposite order.

Returns a list of the pop-up menu's L<Rose::HTML::Form::Field::Option> and/or L<Rose::HTML::Form::Field::OptionGroup> objects in list context, or a reference to an array of the same in scalar context. These are the actual objects used in the field. Modifying them will modify the field itself.

=item B<value [VALUE]>

Simply calls L<input_value()|Rose::HTML::Form::Field/input_value>, passing all arguments.

=item B<value_label [VALUE [, LABEL]]>

If no arguments are passed, it returns the label of the selected option, or the value itself if it has no label. If no option is selected, undef is returned.

With arguments, it will get or set the label for the option whose value is VALUE.  The label for that option is returned. If the option exists, but has no label, then the value itself is returned. If the option does not exist, then undef is returned.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2007 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
