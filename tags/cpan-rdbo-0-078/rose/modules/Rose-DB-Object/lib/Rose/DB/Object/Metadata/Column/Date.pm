package Rose::DB::Object::Metadata::Column::Date;

use strict;

use Rose::DateTime::Util;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Date;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.04';

__PACKAGE__->add_common_method_maker_argument_names('default', 'type');

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->common_method_maker_argument_names ]
);

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_class($type => 'Rose::DB::Object::MakeMethods::Date');
  __PACKAGE__->method_maker_type($type => 'date');
}

sub type { 'date' }

sub should_inline_value
{
  #my($self, $db, $value) = @_;
  return ($_[1]->validate_date_keyword($_[2]) && 
          ($_[1]->driver eq 'Informix' || $_[2] =~ /^\w+\(.*\)$/)) ? 1 : 0;
}

sub parse_value
{
  shift; 
  my $db = shift;
  my $dt = $db->parse_date(@_);

  unless($dt)
  {
    $dt = Rose::DateTime::Util::parse_date($_[0], $db->server_time_zone)
  }

  return $dt;
}

sub format_value { shift; shift->format_date(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Date - Date column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Date;

  $col = Rose::DB::Object::Metadata::Column::Date->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for date columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<date|Rose::DB::Object::MakeMethods::Date/date>, ...

=item C<get>

L<Rose::DB::Object::MakeMethods::Date>, L<date|Rose::DB::Object::MakeMethods::Date/date>, ...

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Date>, L<date|Rose::DB::Object::MakeMethods::Date/date>, ...

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<parse_value DB, VALUE>

Convert VALUE to the equivalent C<DateTime> object.  VALUE maybe returned unmodified if it is a valid date keyword or otherwise has special meaning to the underlying database.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "date".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
