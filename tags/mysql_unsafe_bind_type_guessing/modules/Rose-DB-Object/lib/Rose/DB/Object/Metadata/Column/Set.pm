package Rose::DB::Object::Metadata::Column::Set;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.03';

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(default)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->common_method_maker_argument_names ]
);

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_type($type => 'set');
}

sub type { 'set' }

sub parse_value  { shift; shift->parse_set(@_)  }
sub format_value { shift; shift->format_set(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Set - Set column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Set;

  $col = Rose::DB::Object::Metadata::Column::Set->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for "unordered set" columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<set|Rose::DB::Object::MakeMethods::Generic/set>, ...

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<set|Rose::DB::Object::MakeMethods::Generic/set>, ...

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<set|Rose::DB::Object::MakeMethods::Generic/set>, ...

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<parse_value DB, VALUE>

Parse VALUE and return a reference to an array containing the set values.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "set".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
