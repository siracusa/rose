package Rose::HTML::Form::Field::Time::Hours;

use strict;

use Rose::HTML::Object::Errors qw(:time);

use Rose::HTML::Form::Field::Text;
our @ISA = qw(Rose::HTML::Form::Field::Text);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  boolean => 'military',
);

__PACKAGE__->add_required_html_attrs(
{
  size => 2,
});

sub validate
{
  my($self) = shift;

  my $ok = $self->SUPER::validate(@_);
  return $ok  unless($ok);

  my $value = $self->internal_value;

  unless($value =~ /^\d\d?$/)
  {
    $self->add_error_id(TIME_INVALID_HOUR);
    return 0;
  }

  if($self->military)
  {
    return 1  if($value >= 0 && $value <= 23);
    $self->add_error_id(TIME_INVALID_HOUR);
    return 0;
  }
  else
  {
    return 1  if($value >= 0 && $value <= 12);
    $self->add_error_id(TIME_INVALID_HOUR);
    return 0;
  }

  return 1;
}

1;

__DATA__

[% LOCALE en %]

TIME_INVALID_HOUR = "Invalid hour."

__END__

=head1 NAME

Rose::HTML::Form::Field::Time::Hours - Text field that only accepts valid hours.

=head1 SYNOPSIS

    $field =
       Rose::HTML::Form::Field::Time::Hours->new(
        label => 'Hours', 
        name  => 'hrs');

    $field->input_value(99);
    $field->validate; # 0

    $field->input_value(20);
    $field->validate; # 0

    $field->military(1);
    $field->validate; # 1

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Time::Hours> is a subclass of L<Rose::HTML::Form::Field::Text> that only accepts valid hours.  It supports normal (0-12) and military (0-23) time.  The behavior is toggled via the L<military|/military> object method.  Leading zeros are optional.

=head1 OBJECT METHODS

=over 4

=item B<military [BOOL]>

Get or set the boolean flag that indicates whether or not the field will accept "military time."  If true, the hours 0-23 are valid.  If false, only 0-12 are valid.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
