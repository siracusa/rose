package Rose::HTML::Form::Field::DateTime;

use strict;

use Rose::DateTime::Util();
use Rose::DateTime::Parser;

use Rose::HTML::Form::Field::Text;
our @ISA = qw(Rose::HTML::Form::Field::Text);

our $VERSION = '0.012';

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => 
  [
    'date_parser',
    'output_format',
  ]
);

__PACKAGE__->add_required_html_attr(
{
  size => 25,
});

sub init_date_parser { Rose::DateTime::Parser->new() }

sub time_zone
{
  my($self) = shift;

  my $parser = $self->date_parser;

  return $parser->time_zone(@_)  if($parser->can('time_zone'));
  return undef;
}

sub inflate_value
{
  my($self, $date) = @_;
  return undef  unless(ref $date || (defined $date && length $date));
  return $self->date_parser->parse_datetime($date);
}

sub init_output_format { '%Y-%m-%d %I:%M:%S %p' }

sub deflate_value
{
  my($self, $date) = @_;
  return $self->input_value_filtered  unless($date);
  return Rose::DateTime::Util::format_date($date, $self->output_format);
}

sub validate
{
  my($self) = shift;

  my $ok = $self->SUPER::validate(@_);
  return $ok  unless($ok);

  my $date = $self->internal_value;
  return 1  if(ref $date eq 'DateTime');

  my $input = $self->input_value_filtered;
  return 1  unless(length $input);

  $date = $self->date_parser->parse_datetime($input);

  unless(defined $date)
  {
    $self->error($self->date_parser->error)
      if($self->date_parser->can('error'));

    # XXX: I don't remember what I was thinking here...
    #if($error =~ /^(?:Invalid |Could not parse)/)
    #{
    #  $error =~ s/\s+\(.*\)//;
    #  $self->error($error);
    #}
    #else
    #{
    #  $self->error('Invalid date: '. $self->input_value);
    #}

    return 0;
  }

  die "This should never be reached!";
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::DateTime - Text field that inflates valid dates into
C<DateTime> objects.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::DateTime->new(
        label   => 'Date',
        name    => 'date', 
        default => '12/31/2002 8pm');

    print $field->internal_value; # "2002-12-31T20:00:00"
    print $field->output_value;   # "2002-12-31 08:00:00 PM"

    $field->input_value('blah');

    # "Could not parse date: blah"
    $field->validate or warn $field->error;

    $field->input_value('4/30/1980 5:30 p.m.');

    $dt = $field->internal_value; # DateTime object

    print $dt->hour;     # 17
    print $dt->day_name; # Wednesday

    print $field->html;
    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::DateTime> is a subclass of
L<Rose::HTML::Form::Field::Text> that allows only valid dates as input, which
it then coerces to C<DateTime> objects. It overrides the C<validate()>,
C<inflate_value()>, and C<deflate_value()> methods of its parent class.

Valid input is converted to the format "YYYY-MM-DD HH:MM:SS AM/PM" on output.

=head1 OBJECT METHODS

=over 4

=item B<date_parser [PARSER]>

Get or set the date parser object.  This object must include a C<parse_datetime()>
method that takes a single string as an argument and returns a C<DateTime>
object, or undef if parsing fails.

If the parser object has an C<error()> method, it will be called to set the
error message after a failed parsing attempt.

The parser object defaults to L<Rose::DateTime::Parser-E<gt>new()|Rose::DateTime::Parser/new>.

=item B<output_format [FORMAT]>

Get or set the format string passed to L<Rose::DateTime::Util>'s L<format_date|Rose::DateTime::Util/format_date> function in order to generate the field's output value.  Defaults to "%Y-%m-%d %I:%M:%S %p"

=item B<time_zone [TZ]>

If the parser object has a C<time_zone()> method, this method simply calls it,
passing all arguments.  Otherwise, undef is returned.

=back

=head1 SEE ALSO

Other examples of custom fields:

=over 4

=item L<Rose::HTML::Form::Field::Email>

A text field that only accepts valid email addresses.

=item L<Rose::HTML::Form::Field::Time>

Uses inflate/deflate to coerce input into a fixed format.

=item L<Rose::HTML::Form::Field::DateTime::Range>

A compound field whose internal value consists of more than one object.

=item L<Rose::HTML::Form::Field::PhoneNumber::US::Split>

A simple compound field that coalesces multiple subfields into a single value.

=item L<Rose::HTML::Form::Field::DateTime::Split::MonthDayYear>

A compound field that uses inflate/deflate convert input from multiple
subfields into a C<DateTime> object.

=item L<Rose::HTML::Form::Field::DateTime::Split::MDYHMS>

A compound field that includes other compound fields and uses inflate/deflate 
convert input from multiple subfields into a C<DateTime> object.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
