package Rose::HTML::Form::Field::PhoneNumber::US;

use strict;

use Rose::HTML::Form::Field::Text;
our @ISA = qw(Rose::HTML::Form::Field::Text);

our $VERSION = '0.011';

__PACKAGE__->add_required_html_attrs(
{
  maxlength => 14,
});

sub validate
{
  my($self) = shift;

  my $number = $self->value;

  return 1  if($number !~ /\S/);

  $number =~ s/\D+//g;

  return 1  if(length $number == 10);

  $self->error("Phone number must be 10 digits, including area code");

  return;
}

sub inflate_value
{
  my($self, $value) = @_;

  return  unless(defined $value);

  $value =~ s/\D+//g;

  if($value =~ /^(\d{3})(\d{3})(\d{4})$/)
  {
    return "$1-$2-$3";
  }

  return $_[1];
}

*deflate_value = \&inflate_value;

1;


__END__

=head1 NAME

Rose::HTML::Form::Field::PhoneNumber::US - Text field that accepts only input
that contains exactly 10 digits, and coerces valid input into US phone numbers
in the form: 123-456-7890

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::PhoneNumber::US->new(
        label => 'Phone', 
        name  => 'phone',
        size  => 20);

    $field->input_value('555-5555');

    # "Phone number must be 10 digits, including area code"
    $field->validate or warn $field->error;

    $field->input_value('(123) 456-7890');

    print $field->internal_value; # "123-456-7890"

    print $field->html;
    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::PhoneNumber::US> is a subclass of
L<Rose::HTML::Form::Field::Text> that only allows values that contain exactly
10 digits, which it coerces into the form "123-456-7890".  It overrides the
C<validate()> and C<inflate_value()>, and C<deflate_value()> methods of its
parent class.

This is a good example of a custom field class that constrains the kinds of
inputs that it accepts and coerces all valid input and output to a particular
format.  See L<Rose::HTML::Form::Field::Time> for another example, and a list
of more complex examples.

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
