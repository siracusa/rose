package Rose::DB::Object::Metadata::Column::DatetimeYearToMinute;

use strict;

use Rose::DB::Object::Metadata::Column::Datetime;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Datetime);

our $VERSION = '0.03';

sub type { 'datetime year to minute' }

sub should_inline_value
{
  #my($self, $db, $value) = @_;
  return ($_[1]->validate_datetime_year_to_minute_keyword($_[2]) && 
          ($_[1]->driver eq 'Informix' || $_[2] =~ /^\w+\(.*\)$/)) ? 1 : 0;
}

sub parse_value  { shift; shift->parse_datetime_year_to_minute(@_)  }
sub format_value { shift; shift->format_datetime_year_to_minute(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::DatetimeYearToMinute - Datetime year to minute column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::DatetimeYearToMinute;

  $col = 
    Rose::DB::Object::Metadata::Column::DatetimeYearToMinute->new(...);

  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for "datetime year to minute" columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Datetime>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Datetime> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Date>, L<datetime|Rose::DB::Object::MakeMethods::Date/datetime>, C<type =E<gt> 'datetime year to minute', ...>

=item C<get>

L<Rose::DB::Object::MakeMethods::Date>, L<datetime|Rose::DB::Object::MakeMethods::Date/datetime>, C<type =E<gt> 'datetime year to minute', ...>

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Date>, L<datetime|Rose::DB::Object::MakeMethods::Date/datetime>, C<type =E<gt> 'datetime year to minute', ...>

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<parse_value DB, VALUE>

Convert VALUE to the equivalent C<DateTime> object suitable for storage in a "datetime year to minute" column.  VALUE maybe returned unmodified if it is a valid "datetime year to minute" keyword or otherwise has special meaning to the underlying database.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "datetime year to minute".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
