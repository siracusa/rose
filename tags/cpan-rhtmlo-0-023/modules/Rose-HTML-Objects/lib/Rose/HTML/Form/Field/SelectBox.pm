package Rose::HTML::Form::Field::SelectBox;

use strict;

use Carp();

use Rose::HTML::Form::Field::Option::Container;
our @ISA = qw(Rose::HTML::Form::Field::Option::Container);

__PACKAGE__->add_required_html_attrs(
{
  name => '',
  size => 5,
});

__PACKAGE__->add_boolean_html_attrs
(
  'multiple',
);

__PACKAGE__->add_valid_html_attrs
(
  'onchange',    # %Script;       #IMPLIED  -- the element value was changed --
);

our $VERSION = '0.012';

sub multiple { shift->html_attr('multiple', @_) }

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::SelectBox - Object representation of a select box
in an HTML form.

=head1 SYNOPSIS

    $field = Rose::HTML::Form::Field::SelectBox->new(name => 'fruits');

    $field->options(apple  => 'Apple',
                    orange => 'Orange',
                    grape  => 'Grape');

    print $field->value_label('apple'); # 'Apple'

    $field->input_value('orange');
    print $field->internal_value; # 'orange'

    $field->multiple(1);
    $field->add_value('grape');
    print join(',', $field->internal_value); # 'grape,orange'

    $field->has_value('grape'); # true
    $field->has_value('apple'); # false

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::SelectBox> is an object representation of a 
select box field in an HTML form.

This class inherits from, and follows the conventions of,
L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not
be documented a second time here.  See the L<Rose::HTML::Form::Field>
documentation for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    accesskey
    class
    dir
    id
    lang
    multiple
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

    multiple

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::SelectBox> object based on PARAMS,
where PARAMS are name/value pairs.  Any object method is a valid parameter
name.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_option OPTION>

Convenience alias for C<add_options()>.

=item B<add_options OPTIONS>

Adds options to the select box.  OPTIONS may be a reference to a hash of
value/label pairs, a reference to an array of values, or a list of objects
that are of, or inherit from, the classes L<Rose::HTML::Form::Field::Option>
or L<Rose::HTML::Form::Field::OptionGroup>. Passing an odd number of items in
the value/label argument list causes a fatal error. Options passed as a hash
reference are sorted by value according to the default behavior of Perl's
built-in C<sort()> function.  Options are added to the end of the existing
list of options.

=item B<add_value VALUE>

Add VALUE to the list of selected values.

=item B<add_values VALUE1, VALUE2, ...>

Add multiple values to the list of selected values.

=item B<has_value VALUE>

Returns true if VALUE is selected in the select box, false otherwise.

=item B<labels [LABELS]>

Get or set the labels for all values.  If LABELS is a reference to a hash or a
list of value/label pairs, then LABELS replaces all existing labels.  Passing an
odd number of items in the list version of LABELS causes a fatal error.

Returns a hash of value/label pairs in list context, or a reference to a hash
in scalar context.

=item B<multiple [BOOL]>

This is just an accessor method for the "multiple" boolean HTML attribute, but
I'm documenting it here so that I can warn that trying to select multiple
values in a non-multiple-valued select box will cause a fatal error.

=item B<option VALUE>

Returns the first option (according to the order that they are returned from
C<options()>) whose "value" HTML attribute is VALUE, or undef if no such
option exists.

=item B<options OPTIONS>

Get or set the full list of options in the select box.  OPTIONS may be a
reference to a hash of value/label pairs, a reference to an array of values,
or a list of objects that are of, or inherit from, the classes
L<Rose::HTML::Form::Field::Option> or L<Rose::HTML::Form::Field::OptionGroup>.
Passing an odd number of items in the value/label argument list causes a fatal
error. Options passed as a hash reference are sorted by value according to the
default behavior of Perl's built-in C<sort()> function.

To set an ordered list of option values along with labels in the constructor,
use both the C<options()> and C<labels()> methods in the correct order. 
Example:

    $field = 
      Rose::HTML::Form::Field::SelectBox->new(
        name    => 'fruits',
        options => [ 'apple', 'pear' ],
        labels  => { apple => 'Apple', pear => 'Pear' });

Remember that methods are called in the order that they appear in the
constructor arguments (see the L<Rose::Object> documentation), so C<options()>
will be called before C<labels()> in the example above.  This is important; it
will not work in the opposite order.

Returns a list of the select box's L<Rose::HTML::Form::Field::Option> and/or
L<Rose::HTML::Form::Field::OptionGroup> objects in list context, or a
reference to an array of the same in scalar context. These are the actual
objects used in the field. Modifying them will modify the field itself.

=item B<value [VALUE]>

Simply calls C<input_value()>, passing all arguments.

=item B<values [VALUE]>

Simply calls C<input_value()>, passing all arguments.

=item B<value_label>

Returns the label of the first selected value (according to the order that
they are returned by C<internal_value()>), or the value itself if it has no
label. If no value is selected, undef is returned.

=item B<value_labels>

Returns an array (in list context) or reference to an array (in scalar
context) of the labels of the selected values.  If a value has no label, the
value itself is substituted.  If no values are selected, then an empty
array (in list context) or reference to an empty array (in scalar context) is
returned.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
