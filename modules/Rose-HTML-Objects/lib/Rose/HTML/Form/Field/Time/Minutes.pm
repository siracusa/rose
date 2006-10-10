package Rose::HTML::Form::Field::Time::Minutes;

use strict;

use Rose::HTML::Object::Errors qw(:time);

use Rose::HTML::Form::Field::Text;
our @ISA = qw(Rose::HTML::Form::Field::Text);

our $VERSION = '0.541';

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

  unless($value =~ /^\d\d?$/ && $value >= 0 && $value <= 59)
  {
    $self->add_error_id(TIME_INVALID_MINUTE);
    return 0;
  }

  return 1;
}

1;

__DATA__

[% LOCALE en %]

TIME_INVALID_MINUTE = "Invalid minute."

[% LOCALE de %]

TIME_INVALID_MINUTE  = "Ungültige Minuten."

__END__

=head1 NAME

Rose::HTML::Form::Field::Time::Minutes - Text field that only accepts valid minutes.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::Time::Minutes->new(
        label => 'Minutes', 
        name  => 'mins');

    $field->input_value(99);
    $field->validate; # 0

    $field->input_value(20);
    $field->validate; # 1

    print $field->html;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Time::Minutes> is a subclass of L<Rose::HTML::Form::Field::Text> that only accepts valid minutes: numbers between 0 and 59, inclusive, with or without leading zeros.

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
