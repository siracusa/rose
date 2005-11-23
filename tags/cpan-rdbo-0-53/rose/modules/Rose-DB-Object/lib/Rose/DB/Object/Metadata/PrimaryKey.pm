package Rose::DB::Object::Metadata::PrimaryKey;

use strict;

use Rose::DB::Object::Metadata::UniqueKey;
our @ISA = qw(Rose::DB::Object::Metadata::UniqueKey);

our $VERSION = '0.53';

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'generator',
    'sequence_name',
  ],
);

sub init_name { 'primary_key' }

sub auto_init_columns
{
  my($self) = shift;
  my $meta = $self->parent || return [];
  return $meta->convention_manager->auto_primary_key_column_names || [];
}
1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::PrimaryKey - Primary key metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::PrimaryKey;

  $pk = Rose::DB::Object::Metadata::PrimaryKey->new(
          columns => [ 'id', 'type' ]);

  MyClass->meta->primary_key($pk);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for primary keys in a database table.  Each primary key is made up of one or more columns.

=head1 OBJECT METHODS

=over 4

=item B<add_column [COLUMNS]>

This method is an alias for the L<add_columns|/add_columns> method.

=item B<add_columns [COLUMNS]>

Add COLUMNS to the list of columns that make up the primary key.  COLUMNS must be a list or reference to an array of  column names or L<Rose::DB::Object::Metadata::Column>-derived objects.

=item B<columns [COLUMNS]>

Get or set the list of columns that make up the primary key.  COLUMNS must a list or reference to an array of column names or L<Rose::DB::Object::Metadata::Column>-derived objects.

This method returns all of the columns that make up the primary key.  Each column is a L<Rose::DB::Object::Metadata::Column>-derived column object if the primary key's L<parent|/parent> has a column object with the same name, or just the column name otherwise.  In scalar context, a reference to an array of columns is returned.  In list context, a list is returned.

=item B<column_names>

Returns a list (in list context) or reference to an array (in scalar context) of the names of the columns that make up the primary key.

=item B<delete_columns>

Delete the entire list of columns that make up the primary key.

=item B<name [NAME]>

Get or set the name of the primary key.  Traditionally, this is the name of the index that the database uses to maintain the primary key, but databases vary.  If left undefined, the default value is "primary_key".

=item B<parent [META]>

Get or set the L<Rose::DB::Object::Metadata>-derived object that this primary key belongs to.

=item B<sequence_name [NAME]>

Get or set the name of the database sequence (if any) used to generate values for the primary key column.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
