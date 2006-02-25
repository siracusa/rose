package Rose::HTML::Form::Field::Set;

use strict;

use Rose::HTML::Form::Field::TextArea;
our @ISA = qw(Rose::HTML::Form::Field::TextArea);

our $VERSION = '0.01';

sub deflate_value
{
  my($self, $list) = @_;

  return $self->input_value_filtered  unless(ref $list eq 'ARRAY');

  return join(', ', map
  {
    if(/["\\\s,]/)  # needs escaping
    {
      s/\\/\\\\/g; # escape backslashes
      s/"/\\"/g;   # escape double quotes
      qq("$_")     # double quote the whole thing
    }
    else { $_ }
  }
  @$list);
}

sub inflate_value
{
  my($self, $value) = @_;

  return $value  if(ref $value eq 'ARRAY');
  return undef   unless(defined $value);

  my @strings;

  # Extract comma- or whitespace-separated, possibly double-quoted strings
  while(length $value)
  {
    $value =~ s/^(?:(?:\s*,\s*)+|\s+)//;

    last  unless(length($value));

    if($value =~ s/^"((?:[^"\\]+|\\.)*)"//)
    {
      my $string = $1;
      # Interpolate backslash escapes
      my $interpolated = eval qq("$string");

      if($@)
      {
        $self->error(qq(Invalid quoted string: "$string"));
        next;
      }

      push(@strings, $interpolated);
    }
    elsif($value =~ s/^([^,\s]+)//)
    {
      push(@strings, $1);
    }
    else
    {
      $self->error(qq(Could not parse input: parse error at ),
                   ((length($value) < 5) ? qq("...$value") : 
                   q("...) . substr($value, 0, 5) . q(")));
      last;
    }
  }

  return \@strings;
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Field::Set - Text area that accepts whitespace- or comma-separated strings.

=head1 SYNOPSIS

    $field =
      Rose::HTML::Form::Field::Set->new(
        label   => 'States', 
        name    => 'states',
        default => 'NY NJ NM');

    $vals = $field->internal_value;

    print $vals->[1]; # "NJ"

    $field->input_value('NY, NJ, "New Mexico"');

    $vals = $field->internal_value;

    print $vals->[3]; # "New Mexico"

    $field->input_value([ 'New York', 'New Jersey' ]);

    print $field->internal_value->[0]; # "New York"

    ...

=head1 DESCRIPTION

L<Rose::HTML::Form::Field::Set> is a subclass of L<Rose::HTML::Form::Field::TextArea> that accepts  whitespace- or comma-separated strings.  Its internal value is a reference to an array of strings, or undef if the input value could not be parsed.

Strings with spaces, double quotes, backslashes, or commas must be double-quoted.  Use a backslash character "\" to escape double-quotes within double-quoted strings.  Backslashed escapes in double-quoted strings are interpolated according to Perl's rules.

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
