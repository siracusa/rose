package Rose::DB::Object::Metadata::Column::Character;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column::Scalar;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Scalar);

our $VERSION = '0.60';

sub type { 'character' }

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_type($type => 'character')
}

sub parse_value
{
  my $length = $_[0]->length or return $_[2];
  return sprintf("%-*s", $length, $_[2])
}

*format_value = \&parse_value;

sub init_with_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::init_with_dbi_column_info($col_info);

  if(defined $col_info->{'CHAR_OCTET_LENGTH'})
  {
    $self->length($col_info->{'CHAR_OCTET_LENGTH'});
  }

  return;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Character - Character column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Character;

  $col = Rose::DB::Object::Metadata::Column::Character->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for character columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column::Scalar>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column::Scalar> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<character|Rose::DB::Object::MakeMethods::Generic/character>, ...

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<character|Rose::DB::Object::MakeMethods::Generic/character>, ...

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<character|Rose::DB::Object::MakeMethods::Generic/character>, ...

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<parse_value DB, VALUE>

If C<length> is defined, returns VALUE truncated to a maximum of C<length> characters, or padding with spaces to be exactly C<length> characters long.  DB is a L<Rose::DB> object that may be as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "character".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 LICENSE

Copyright (c) 2009 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
