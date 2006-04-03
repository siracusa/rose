package Rose::DB::Object::Metadata::Column::BigInt;

use strict;

use Rose::DB::Object::MakeMethods::BigNum;

use Rose::DB::Object::Metadata::Column::Integer;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Integer);

our $VERSION = '0.70';

__PACKAGE__->method_maker_info
(
  get_set => 
  {
    class => 'Rose::DB::Object::MakeMethods::BigNum',
    type  => 'bigint',
  },

  get =>
  {
    class => 'Rose::DB::Object::MakeMethods::BigNum',
    type  => 'bigint',
  },

  set =>
  {
    class => 'Rose::DB::Object::MakeMethods::BigNum',
    type  => 'bigint',
  },
);

sub type { 'bigint' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::BigInt - Big integer column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::BigInt;

  $col = Rose::DB::Object::Metadata::Column::BigInt->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for big integer (sometimes called "int8") columns in a database.  Values are stored internally and returned as L<Math::BigInt> objects.

This class inherits from L<Rose::DB::Object::Metadata::Column::Integer>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column::Integer> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::BigNum/bigint>, C<interface =E<gt> 'get_set', ...>

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::BigNum/bigint>, C<interface =E<gt> 'get', ...>

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::BigNum/bigint>, C<interface =E<gt> 'set', ...>

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<type>

Returns "bigint".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
