package Rose::HTML::Form::Field::DateTime::Split::MonthDayYear;

use strict;

use Rose::DateTime::Util();

use Rose::HTML::Form::Field::Text;

use Rose::HTML::Form::Field::DateTime::Split;
our @ISA = qw(Rose::HTML::Form::Field::DateTime::Split);

our $VERSION = '0.02';

sub build_field
{
  my($self) = shift;

  my %fields;

  $fields{'month'} = 
    Rose::HTML::Form::Field::Text->new(size      => 2,
                                       maxlength => 2,
                                       class     => 'month');

  $fields{'day'} = 
    Rose::HTML::Form::Field::Text->new(size      => 2,
                                       maxlength => 2,
                                       class     => 'day');
  $fields{'year'} = 
    Rose::HTML::Form::Field::Text->new(size      => 4,
                                       maxlength => 4,
                                       class     => 'year');

  $self->add_fields(%fields);
}

sub decompose_value
{
  my($self, $value) = @_;

  return undef  unless(defined $value);

  my $date = $self->SUPER::inflate_value($value);

  unless($date)
  {
    no warnings;
    return
    {
      month => substr($value, 0, 2) || '',
      day   => substr($value, 2, 2) || '',
      year  => substr($value, 4, 4) || '',
    }
  }

  my($month, $day, $year) = Rose::DateTime::Util::format_date($date, '%m', '%d', '%Y');

  return
  {
    month => $month,
    day   => $day,
    year  => $year,
  };
}

sub is_full
{
  my($self) = shift;

  my $count = grep { defined } 
              map { $self->field($_)->internal_value }  qw(month day year);

  return $count == 3 ? 1 : 0;
}

sub coalesce_value
{
  my($self) = shift;
  return join('/', map { defined($_) ? $_ : '' } 
                   map { $self->field($_)->internal_value }  qw(month day year));
}

sub deflate_value
{
  my($self, $date) = @_;
  return $self->input_value_filtered  unless($date);
  return Rose::DateTime::Util::format_date($date, '%m/%d/%Y');
}

sub html_field
{
  my($self) = shift;

  return '<span class="date">' .
         $self->field('month')->html_field . '/' .
         $self->field('day')->html_field   . '/' .
         $self->field('year')->html_field .
         '</span>';
}

sub xhtml_field
{
  my($self) = shift;

  return '<span class="date">' .
         $self->field('month')->xhtml_field . '/' .
         $self->field('day')->xhtml_field   . '/' .
         $self->field('year')->xhtml_field .
         '</span>';
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::DateTime::Split::MonthDayYear - Compound field for dates with separate text fields for month, day, and year.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::DateTime::Split::MonthDayYear->new(
        label   => 'Date',
        name    => 'date', 
        default => '12/31/2002');

    print $field->field('month')->internal_value; # "12"

    print $field->internal_value; # "2002-12-31T20:00:00"
    print $field->output_value;   # "2002-12-31 08:00:00 PM"

    $field->input_value('blah');

    # "Could not parse date: blah"
    $field->validate or warn $field->error;

    $field->input_value('4/30/1980');

    $dt = $field->internal_value; # DateTime object

    print $dt->hour;     # 17
    print $dt->day_name; # Wednesday

    print $field->html;
    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::DateTime::Split::MonthDayYear> a compound field for dates with separate text fields for month, day, and year.

This class inherits (indirectly) from both L<Rose::HTML::Form::Field::DateTime> and L<Rose::HTML::Form::Field::Compound>.  This doesn't quite work out as expected without a bit of tweaking.  We'd like L<inflate_value()|Rose::HTML::Form::Field/inflate_value> and L<validate()|Rose::HTML::Form::Field/validate> methods to be inherited from L<Rose::HTML::Form::Field::DateTime>, but everything else to be inherited from L<Rose::HTML::Form::Field::Compound>.

To solve this problem, there's an intermediate class that imports the correct set of methods.  This class then inherits from the intermediate class.  This works, and isolates the tricky bits to a single intermediate class, but it also demonstrates the problems that can crop up when multiple inheritance is combined with a strong aversion to code duplication.

Inheritence shenanigans aside, this class is a good example of a compound field that also provides an "inflated" internal value (a L<DateTime> object).

It is important that this class (indirectly) inherits from L<Rose::HTML::Form::Field::Compound>. See the L<Rose::HTML::Form::Field::Compound> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<date_parser [PARSER]>

Get or set the date parser object.  This object must include a C<parse_datetime()> method that takes a single string as an argument and returns a L<DateTime> object, or undef if parsing fails.

If the parser object has an C<error()> method, it will be called to set the error message after a failed parsing attempt.

The parser object defaults to L<Rose::DateTime::Parser-E<gt>new()|Rose::DateTime::Parser/new>.

=item B<time_zone [TZ]>

If the parser object has a L<time_zone()|/time_zone> method, this method simply calls it, passing all arguments.  Otherwise, undef is returned.

=back

=head1 SEE ALSO

Other examples of custom fields:

=over 4

=item L<Rose::HTML::Form::Field::Email>

A text field that only accepts valid email addresses.

=item L<Rose::HTML::Form::Field::Time>

Uses inflate/deflate to coerce input into a fixed format.

=item L<Rose::HTML::Form::Field::DateTime>

Uses inflate/deflate to convert input to a L<DateTime> object.

=item L<Rose::HTML::Form::Field::DateTime::Range>

A compound field whose internal value consists of more than one object.

=item L<Rose::HTML::Form::Field::PhoneNumber::US::Split>

A simple compound field that coalesces multiple subfields into a single value.

=item L<Rose::HTML::Form::Field::DateTime::Split::MDYHMS>

A compound field that includes other compound fields and uses inflate/deflate convert input from multiple subfields into a L<DateTime> object.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
