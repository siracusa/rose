package Rose::HTML::Form::Field::OnOff;

use strict;

use Rose::HTML::Form::Field::Input;
our @ISA = qw(Rose::HTML::Form::Field::Input);

our $VERSION = '0.011';

__PACKAGE__->add_required_html_attrs(
{
  value => 'on',
});

sub value { shift->html_attr('value', @_) }

sub value_label { $_[0]->is_on ? $_[0]->label : undef }

sub internal_value { $_[0]->is_on ? $_[0]->html_attr('value') : undef }
sub output_value   { $_[0]->is_on ? $_[0]->html_attr('value') : undef }

1;
