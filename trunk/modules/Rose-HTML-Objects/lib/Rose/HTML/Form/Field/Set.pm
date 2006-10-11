package Rose::HTML::Form::Field::Set;

use strict;

use Rose::HTML::Object::Errors qw(:set);

use Rose::HTML::Form::Field::TextArea;
our @ISA = qw(Rose::HTML::Form::Field::TextArea);

our $VERSION = '0.541';

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

    if($value =~ s/^"((?:[^"\\]+|\\.)*)"//s)
    {
      my $string = $1;
      # Interpolate backslash escapes
      my $interpolated = $string;
      $interpolated =~ s/\\(.)/eval qq("\\$1")/ge;

      if($@)
      {
        $self->add_error_id(SET_INVALID_QUOTED_STRING, { string => $string });
        next;
      }

      push(@strings, $interpolated);
    }
    elsif($value =~ s/^([^,"\s]+)//)
    {
      push(@strings, $1);
    }
    else
    {
      $self->error(SET_PARSE_ERROR, { context => (length($value) < 5) ? "...$value" : 
                                                 '...' . substr($value, 0, 5) });
      last;
    }
  }

  return \@strings;
}

if(__PACKAGE__->localizer->auto_load_messages)
{
  __PACKAGE__->localizer->load_all_messages;
}

1;

__DATA__

[% LOCALE en %]

SET_INVALID_QUOTED_STRING = "Invalid quoted string: \"[string]\""  # Testing parser "
SET_PARSE_ERROR = "Could not parse input: parse error at \[[context]\]"

[% LOCALE de %]

SET_INVALID_QUOTED_STRING = "Ungültig gequoteter String: \"[string]\""
SET_PARSE_ERROR = "Konnte Eingabe nicht parsen: Fehler bei \[[context]\]"

[% LOCALE fr %]

SET_INVALID_QUOTED_STRING = "Texte entre guillemets invalide: \"[string]\""
SET_PARSE_ERROR = "Impossible d'évaluer la saisie : erreur à \[[context]\]"

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
