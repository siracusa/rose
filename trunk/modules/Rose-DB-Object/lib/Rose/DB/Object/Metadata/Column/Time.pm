package Rose::DB::Object::Metadata::Column::Time;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Time;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.74';

__PACKAGE__->add_common_method_maker_argument_names('default', 'precision');

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ precision => { default => 0 } ],
  scalar => [ __PACKAGE__->common_method_maker_argument_names ]
);

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_class($type => 'Rose::DB::Object::MakeMethods::Time');
  __PACKAGE__->method_maker_type($type => 'time');
}

sub type { 'time' }

sub init_with_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::init_with_dbi_column_info($col_info);
  $self->precision($col_info->{'TIME_PRECISION'});

  return;
}

sub should_inline_value
{
  #my($self, $db, $value) = @_;
  no warnings 'uninitialized';
  return ($_[1]->validate_time_keyword($_[2]) || $_[2] =~ /^\w+\(.*\)$/) ? 1 : 0;
}

sub method_should_set
{
  my($self, $type, $args) = @_;

  return 1  if($type eq 'set' || $type eq 'get_set');
  return 0  if($type eq 'get');

  return $self->SUPER::method_should_set($type, $args);
}

sub parse_value  { shift; shift->parse_time(@_)  }
sub format_value { shift; shift->format_time(@_) }

sub method_uses_formatted_key
{
  my($self, $type) = @_;
  return 1  if($type eq 'get' || $type eq 'set' || $type eq 'get_set');
  return 0;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Time - Time column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Time;

  $col = Rose::DB::Object::Metadata::Column::Time->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for time columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<date|Rose::DB::Object::MakeMethods::Time/time>, ...

=item C<get>

L<Rose::DB::Object::MakeMethods::Time>, L<date|Rose::DB::Object::MakeMethods::Time/time>, ...

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Time>, L<date|Rose::DB::Object::MakeMethods::Time/time>, ...

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<parse_value DB, VALUE>

Convert VALUE to the equivalent L<Time::Clock> object.  VALUE maybe returned unmodified if it is a valid time keyword or otherwise has special meaning to the underlying database.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<precision [INT]>

Get or set the integer number of places past the decimal point preserved for fractional seconds.  Defaults to 0.

Returns "time".

=item B<type>

Returns "time".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
