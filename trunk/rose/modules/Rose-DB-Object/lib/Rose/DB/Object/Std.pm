package Rose::DB::Object::Std;

use strict;

use Rose::DB::Object::Std::Metadata;

use Rose::DB::Object;
our @ISA = qw(Rose::DB::Object);

our $VERSION = '0.021';

our $Debug = 0;

#
# Class methods
#

sub meta_class { 'Rose::DB::Object::Std::Metadata' }

#
# Object methods
#

# Better to leave this up to the database...
# sub insert
# {
#   my($self) = shift;
#   
#   my $meta = $self->meta;
# 
#   if($meta->column('date_created'))
#   {
#     $self->date_created('now')  unless($self->date_created);
#   }
# 
#   if($meta->column('last_modified'))
#   {
#     $self->last_modified('now');
#   }
#   
#   $self->SUPER::insert(@_);
# }
# 
# sub update
# {
#   my($self) = shift;
# 
#   if($self->meta->column('last_modified'))
#   {
#     $self->last_modified('now');
#   }
#   
#   $self->SUPER::update(@_);
# }

1;

__END__

=head1 NAME

Rose::DB::Object::Std - Standardized object representation of a single row in a database table.

=head1 SYNOPSIS

  package Category;

  use Rose::DB::Object::Std;
  our @ISA = qw(Rose::DB::Object::Std);

  __PACKAGE__->meta->table('categories');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
  );

  __PACKAGE__->meta->add_unique_key('name');

  __PACKAGE__->meta->initialize;

  ...

  package Product;

  use Rose::DB::Object::Std;
  our @ISA = qw(Rose::DB::Object::Std);

  __PACKAGE__->meta->table('products');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
    category_id => { type => 'int' },

    status => 
    {
      type      => 'varchar', 
      check_in  => [ 'active', 'inactive' ],
      default   => 'inactive',
    },

    start_date  => { type => 'datetime' },
    end_date    => { type => 'datetime' },

    date_created     => { type => 'timestamp', default => 'now' },  
    last_modified    => { type => 'timestamp', default => 'now' },
  );

  __PACKAGE__->meta->add_unique_key('name');

  __PACKAGE__->meta->foreign_keys
  (
    category =>
    {
      class       => 'Category',
      key_columns =>
      {
        category_id => 'id',
      }
    },
  );

  __PACKAGE__->meta->initialize;

  ...

  $product = Product->new(name        => 'GameCube',
                          status      => 'active',
                          start_date  => '11/5/2001',
                          end_date    => '12/1/2007',
                          category_id => 5);

  $product->save or die $product->error;

  $id = $product->id; # auto-generated on save

  ...

  $product = Product->new(id => $id);
  $product->load or die $product->error;

  print $product->category->name;

  $product->end_date->add(days => 45);

  $product->save or die $product->error;

  ...

=head1 DESCRIPTION

L<Rose::DB::Object::Std> is a subclass of L<Rose::DB::Object> that imposes a few more constraints on the tables it fronts.  In addition to the constraints described in the L<Rose::DB::Object> documentation, tables fronted by L<Rose::DB::Object::Std> objects must also fulfill the following requirements:

=over 4

=item * The table must have a single primary key column named "id"

=item * The value of the "id" column must be auto-generated if absent.

=back

Different databases provide for auto-generated column values in different ways.  Some provide a native "auto-increment" or "serial" data type, others use sequences behind the scenes.

L<Rose::DB::Object::Std> (in cooperation with L<Rose::DB> and L<Rose::DB::Object::Std::Metadata>) attempts to hide these details from you.  All you have to do is omit the value for the primary key entirely.  After the object is C<save()>ed, you can retrieve the auto-selected primary key by calling the C<id()> method.

You do have to correctly define the "id" column in the database, however.  Here are examples of primary key column definitions that provide auto-generated values, one for each of the databases supported by L<Rose::DB>.

=over

=item * PostgreSQL

    CREATE TABLE mytable
    (
      id   SERIAL NOT NULL PRIMARY KEY,
      ...
    );

=item * MySQL

    CREATE TABLE mytable
    (
      id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      ...
    );

=item * Informix

    CREATE TABLE mytable
    (
      id   SERIAL NOT NULL PRIMARY KEY,
      ...
    );

=back

Other data definitions are possible, of course, but the three definitions above are used in the L<Rose::DB::Object::Std> test suite and are therefore guaranteed to work.  If you have success with alternative approaches, patches and/or new tests are welcome.

To achieve much of this functionality, L<Rose::DB::Object::Std> uses L<Rose::DB::Object::Std::Metadata> objects.  The C<meta()> method will create these form you.  You should not need to do anything special if you use the idimoatic approach to defining metadata as shown in the L<synopsis|/SYNOPSIS>.  

=head1 METHODS

Only the methods that are overridden are documented here.  See the L<Rose::DB::Object> documentation for the rest.

=over 4

=item B<meta>

Returns the L<Rose::DB::Object::Std::Metadata> object associated with this class.  This object describes the database table whose rows are fronted by this class: the name of the table, its columns, unique keys, foreign keys, etc.  See the L<Rose::DB::Object::Std::Metadata> documentation for more information.

This can be used as both a class method and an object method.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
