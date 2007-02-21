package Rose::DB::Object::Metadata::Column::Blob;

use strict;

use Rose::DB::Object::Metadata::Column::Text;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Text);

our $VERSION = '0.01';

sub type { 'blob' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Blob - Binary large object column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Blob;

  $col = Rose::DB::Object::Metadata::Column::Blob->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for long, variable-length character-based columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column::Character>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column::Character> documentation for more information.

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

=item B<type>

Returns "blob".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.