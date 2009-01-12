package Rose::DB::Object::Std::Cached;

use strict;

use Rose::DB::Object::Std;
use Rose::DB::Object::Cached;
our @ISA = qw(Rose::DB::Object::Cached Rose::DB::Object::Std);

our $VERSION = '0.02';

*meta_class = \&Rose::DB::Object::Std::meta_class;

1;

__END__

=head1 NAME

Rose::DB::Object::Std::Cached - Memory cached standardized object representation of a single row in a database table.

=head1 SYNOPSIS

  package Category;

  use Rose::DB::Object::Std::Cached;
  our @ISA = qw(Rose::DB::Object::Std::Cached);

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

  $cat1 = Category->new(id   => 123,
                        name => 'Art');

  $cat1->save or die $category->error;


  $cat2 = Category->new(id => 123);

  # This will load from the memory cache, not the database
  $cat2->load or die $cat2->error; 

  # $cat2 is the same object as $cat1
  print "Yep, cached"  if($cat1 eq $cat2);

  # No, really, it's the same object
  $cat1->name('Blah');
  print $cat2->name; # prints "Blah"

  ...

=head1 DESCRIPTION

C<Rose::DB::Object::Std::Cached> is a subclass of both L<Rose::DB::Object::Std> and L<Rose::DB::Object::Cached>.  It simply combines the features of both classes.  See the L<Rose::DB::Object::Std> and L<Rose::DB::Object::Cached> documentation for more information.

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 LICENSE

Copyright (c) 2009 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
