package Rose::HTML::Form::Field::CheckBoxGroup;

use strict;

use Carp;

use Rose::HTML::Form::Field::CheckBox;

use Rose::HTML::Form::Field::Group;
use Rose::HTML::Form::Field::Group::OnOff;
our @ISA = qw(Rose::HTML::Form::Field::Group::OnOff);

our $VERSION = '0.012';

sub _item_class       { 'Rose::HTML::Form::Field::CheckBox' }
sub _item_name        { 'checkbox' }
sub _item_name_plural { 'checkboxes' }

*checkboxes = \&Rose::HTML::Form::Field::Group::items;

*checkbox       = \&Rose::HTML::Form::Field::Group::OnOff::item;
*add_checkboxes = \&Rose::HTML::Form::Field::Group::add_items;
*add_checkbox   = \&add_checkboxes;

sub html_table
{
  my($self, %args) = @_;

  $args{'cellpadding'} = 2  unless(exists $args{'cellpadding'});
  $args{'cellspacing'} = 0  unless(exists $args{'cellspacing'});
  $args{'tr'} = { valign => 'top' }  unless(exists $args{'tr'});
  $args{'td'} ||= {};

  $args{'table'}{'cellpadding'} = $args{'cellpadding'}
    unless((exists $args{'table'} && !defined $args{'table'}) || 
           exists $args{'table'}{'cellpadding'});

  $args{'table'}{'cellspacing'} = $args{'cellspacing'}
    unless((exists $args{'table'} && !defined $args{'table'}) ||
           exists $args{'table'}{'cellspacing'});

  return
    $self->SUPER::html_table(items       => scalar $self->checkboxes,
                             format_item => \&Rose::HTML::Form::Field::Group::_html_item,
                             %args);
}

*xhtml_table = \&html_table;

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::CheckBoxGroup - A group of checkboxes in an HTML form.

=head1 SYNOPSIS

    $field = 
      Rose::HTML::Form::Field::CheckBoxGroup->new(name => 'fruits');

    $field->checkboxes(apple  => 'Apple',
                       orange => 'Orange',
                       grape  => 'Grape');

    print $field->value_label('apple'); # 'Apple'

    $field->input_value('orange');
    print $field->internal_value; # 'orange'

    $field->add_value('grape');
    print join(',', $field->internal_value); # 'grape,orange'

    $field->has_value('grape'); # true
    $field->has_value('apple'); # false

    print $field->html_table(columns => 2);

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::CheckBoxGroup> is an object wrapper for a group of checkboxes in an HTML form.

This class inherits from, and follows the conventions of, L<Rose::HTML::Form::Field>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Form::Field> documentation for more information.

=head1 HTML ATTRIBUTES

None.  This class is simply an aggregator of L<Rose::HTML::Form::Field::CheckBox> objects.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Field::CheckBoxGroup> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_checkbox OPTION>

Convenience alias for C<add_checkboxes()>.

=item B<add_checkboxes CHECKBOXES>

Adds checkboxes to the checkbox group.  CHECKBOXES may be a reference to a hash of value/label pairs, a reference to an array of values, or a list of L<Rose::HTML::Form::Field::CheckBox> objects. Passing an odd number of items in the value/label argument list causes a fatal error. Checkbox values and labels passed as a hash reference are sorted by value according to the default behavior of Perl's built-in L<sort()|perlfunc/sort> function.  Checkboxes are added to the end of the existing list of checkboxes.

=item B<add_value VALUE>

Put a check in the checkbox whose value is VALUE.

=item B<add_values VALUE1, VALUE2, ...>

Put a check in the checkboxes whose values are equal to VALUE1, VALUE2, etc.

=item B<checkbox VALUE>

Returns the first checkbox (according to the order that they are returned from L<checkboxes()|/checkboxes>) whose "value" HTML attribute is VALUE, or undef if no such checkbox exists.

=item B<checkboxes CHECKBOXES>

Get or set the full list of checkboxes in the group.  CHECKBOXES may be a reference to a hash of value/label pairs, a reference to an array of values, or a list of L<Rose::HTML::Form::Field::CheckBox> objects. Passing an odd number of items in the value/label argument list causes a fatal error. Checkbox values and labels passed as a hash reference are sorted by value according to the default behavior of Perl's built-in L<sort()|perlfunc/sort> function.

To set an ordered list of checkboxes along with labels in the constructor, use both the L<checkboxes()|/checkboxes> and L<labels()|/labels> methods in the correct order. Example:

    $field = 
      Rose::HTML::Form::Field::CheckBoxGroup->new(
        name       => 'fruits',
        checkboxes => [ 'apple', 'pear' ],
        labels     => { apple => 'Apple', pear => 'Pear' });

Remember that methods are called in the order that they appear in the constructor arguments (see the L<Rose::Object> documentation), so L<checkboxes()|/checkboxes> will be called before L<labels()|/labels> in the example above.  This is important; it will not work in the opposite order.

Returns a list of the checkbox group's L<Rose::HTML::Form::Field::CheckBox> objects in list context, or a reference to an array of the same in scalar context. These are the actual objects used in the field. Modifying them will modify the field itself.

=item B<columns [COLS]>

Get or set the default number of columns to use in the output of the L<html_table()|/html_table> and L<xhtml_table()|/xhtml_table> methods.

=item B<has_value VALUE>

Returns true if the checkbox whose value is VALUE is checked, false otherwise.

=item B<html>

Returns the HTML for checkbox group, which consists of the L<html()|/html> for each checkbox object joined by L<html_linebreak()|/html_linebreak> if L<linebreak()|/linebreak> is true, or single spaces if it is false.

=item B<html_linebreak [HTML]>

Get or set the HTML linebreak string.  The default is "E<lt>brE<gt>\n"

=item B<html_table [ARGS]>

Returns an HTML table containing the checkboxes.  The table is constructed according ARGS, which are name/value pairs.  Valid arguments are:

=over 4

=item cellpadding

The value of the "table" tag's "cellpadding" HTML attribute. Defaults to 2.

=item cellspacing

The value of the "table" tag's "cellspacing" HTML attribute. Defaults to 0.

=item columns

The number of columns in the table.  Defaults to L<columns()|/columns>, or 1 if L<columns()|/columns> is false.

=item format_item

The name of the method to call on each checkbox object in order to fill each table cell.  Defaults to "html"

=item rows

The number of rows in the table.  Defaults to L<rows()|/rows>, or 1 if L<rows()|/rows> is false.

=item table

A reference to a hash of HTML attribute/value pairs to be used in the "table" tag.  Some attribute values be overridden by the equivalent standalone arguments (e.g., cellpadding and cellspacing).

=item td

A reference to a hash of HTML attribute/value pairs to be used in the "td" tag, or an array of such hashes to be used in order for the table cells of each row.  If the array contains fewer entries than the number of cells in each row of the table, then the last entry is used for all of the remaining cells in the row.  Defaults to a reference to an empty hash, C<{}>.

=item tr

A reference to a hash of HTML attribute/value pairs to be used in the "tr" tag, or an array of such hashes to be used in order for the table rows.  If the array contains fewer entries than the number of rows in the table, then the last entry is used for all of the remaining rows.  Defaults to C<{ valign =E<gt> 'top' }>.

=back

Specifying "rows" and "columns" values (either as ARGS or via L<rows()|/rows> and L<columns()|/columns>) that are both greater than 1 leads to undefined behavior if there are not exactly "rows x columns" checkboxes.  For predictable behavior, set either rows or columns to a value greater than 1, but not both.

To remove HTML attributes that have default values, simply pass undef as the value for those attributes.  Example:

    print $field->html_table();    

    # <table cellpadding="2" cellspacing="0">
    # <tr valign="top">
    # <td>...

    print $field->html_table(table => undef, tr => undef);

    # <table>
    # <tr>
    # <td>...

=item B<label VALUE [, LABEL]>

Get or set the label for the checkbox whose value is VALUE.  The label for that checkbox is returned. If the checkbox exists, but has no label, then the value itself is returned. If the checkbox does not exist, then undef is returned.

=item B<labels [LABELS]>

Get or set the labels for all checkboxes.  If LABELS is a reference to a hash or a list of value/label pairs, then LABELS replaces all existing labels. Passing an odd number of items in the list version of LABELS causes a fatal error.

Returns a hash of value/label pairs in list context, or a reference to a hash in scalar context.

=item B<linebreak [BOOL]>

Get or set the flag that determines whether or not the string stored in L<html_linebreak()|/html_linebreak> or L<xhtml_linebreak()|/xhtml_linebreak> is used to separate checkboxes in the output of L<html()|/html> or L<xhtml()|/xhtml>, respectively.  Defaults to true.

=item B<rows [ROWS]>

Get or set the default number of rows to use in the output of the L<html_table()|/html_table> and L<xhtml_table()|/xhtml_table> methods.

=item B<value [VALUE]>

Simply calls L<input_value()|Rose::HTML::Form::Field/input_value>, passing all arguments.

=item B<values [VALUE]>

Simply calls L<input_value()|Rose::HTML::Form::Field/input_value>, passing all arguments.

=item B<value_label [VALUE [, LABEL]]>

If no arguments are passed, it returns the label of the first selected checkbox (according to the order that they are returned by L<internal_value()|Rose::HTML::Form::Field/internal_value>), or the value itself if it has no label. If no checkbox is selected, undef is returned.

With arguments, it will get or set the label for the checkbox whose value is VALUE.  The label for that checkbox is returned. If the checkbox exists, but has no label, then the value itself is returned. If the checkbox does not exist, then undef is returned.

=item B<value_labels>

Returns an array (in list context) or reference to an array (in scalar context) of the labels of the selected checkboxes.  If a checkbox has no label, the checkbox value is substituted.  If no checkboxes are selected, then an empty array (in list context) or reference to an empty array (in scalar context) is returned.

=item B<xhtml>

Returns the XHTML for checkbox group, which consists of the L<xhtml()|/xhtml> for each checkbox object joined by L<xhtml_linebreak()|/xhtml_linebreak> if L<linebreak()|/linebreak> is true, or single spaces if it is false.

=item B<xhtml_linebreak [XHTML]>

Get or set the XHTML linebreak string.  The default is "E<lt>br /E<gt>\n"

=item B<xhtml_table>

Equivalent to L<html_table()|/html_table>.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
