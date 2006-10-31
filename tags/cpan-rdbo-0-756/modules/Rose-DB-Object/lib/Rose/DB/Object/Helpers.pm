package Rose::DB::Object::Helpers;

use strict;

use Rose::DB::Object::Constants qw(:all);

use Rose::DB::Object::MixIn;
our @ISA = qw(Rose::DB::Object::MixIn);

use Carp;

our $VERSION = '0.756';

__PACKAGE__->export_tags
(
  all => 
  [
    qw(clone clone_and_reset load_or_insert insert_or_update 
       insert_or_update_on_duplicate_key load_speculative
       column_value_pairs column_accessor_value_pairs 
       column_mutator_value_pairs 
       column_values_as_yaml column_values_as_json
       init_with_yaml init_with_json init_with_column_value_pairs
       has_loaded_related) 
  ],

  # This exists for the benefit of the test suite
  all_noprereq =>
  [
    qw(clone clone_and_reset load_or_insert insert_or_update 
       insert_or_update_on_duplicate_key load_speculative
       column_value_pairs column_accessor_value_pairs 
       column_mutator_value_pairs init_with_column_value_pairs
       has_loaded_related)
  ],
);

sub load_speculative { shift->load(@_, speculative => 1) }

sub load_or_insert
{
  my($self) = shift;

  my($ret, @ret);

  if(wantarray)
  {
    @ret = $self->load(@_, speculative => 1);
    return @ret  if($ret[0]);
  }
  else
  {
    $ret = $self->load(@_, speculative => 1);
    return $ret  if($ret);
  }

  return $self->insert;
}

sub insert_or_update
{
  my($self) = shift;

  # Initially trust the metadata
  if($self->{STATE_IN_DB()})
  {
    eval { $self->update };
    return $self || 1  unless($@); 
  }

  my $meta = $self->meta;

  # This is more "correct"
  #my $clone = clone($self);

  # ...but this is a lot faster
  my $clone = bless { %$self }, ref($self);

  if($clone->load(speculative => 1))
  {
    # The long way...
    my %pk;
    @pk{$meta->primary_key_column_mutator_names} = 
      map { $clone->$_() } $meta->primary_key_column_accessor_names;
    $self->init(%pk);

    # The short (but dirty) way
    #my @pk_keys = $meta->primary_key_column_db_value_hash_keys;
    #@$self{@pk_keys} = @$clone{@pk_keys};

    return $self->update(@_);
  }

  return $self->insert(@_);
}

sub insert_or_update_on_duplicate_key
{
  my($self) = shift;

  unless($self->db->supports_on_duplicate_key_update)
  {
    return insert_or_update($self, @_);
  }

  return $self->insert(@_, on_duplicate_key_update => 1);
}

__PACKAGE__->pre_import_hook(column_values_as_yaml => sub { require YAML::Syck });

sub column_values_as_yaml
{
  local $_[0]->{STATE_SAVING()} = 1;
  YAML::Syck::Dump(scalar Rose::DB::Object::Helpers::column_value_pairs(shift))
}

__PACKAGE__->pre_import_hook(column_values_as_json => sub { require JSON::Syck });

sub column_values_as_json
{
  local $_[0]->{STATE_SAVING()} = 1;
  JSON::Syck::Dump(scalar Rose::DB::Object::Helpers::column_value_pairs(shift))
}

__PACKAGE__->pre_import_hook(init_with_json => sub { require YAML::Syck });

sub init_with_yaml
{
  my($self, $yaml) = @_;

  my $hash = YAML::Syck::Load($yaml);
  my $meta = $self->meta;

  local $self->{STATE_LOADING()} = 1;

  while(my($column, $value) = each(%$hash))
  {
    next  unless(length $column);
    my $method = $meta->column($column)->mutator_method_name;
    $self->$method($value);
  }

  return $self;
}

__PACKAGE__->pre_import_hook(init_with_json => sub { require JSON::Syck });

sub init_with_json
{
  my($self, $json) = @_;

  my $hash = JSON::Syck::Load($json);
  my $meta = $self->meta;

  local $self->{STATE_LOADING()} = 1;

  while(my($column, $value) = each(%$hash))
  {
    next  unless(length $column);
    my $method = $meta->column($column)->mutator_method_name;
    $self->$method($value);
  }

  return $self;
}

sub init_with_column_value_pairs
{
  my($self) = shift;

  my $hash = @_ == 1 ? shift : { @_ };
  my $meta = $self->meta;

  local $self->{STATE_LOADING()} = 1;

  while(my($column, $value) = each(%$hash))
  {
    next  unless(length $column);
    my $method = $meta->column($column)->mutator_method_name;
    $self->$method($value);
  }

  return $self;
}

sub column_value_pairs
{
  my($self) = shift;

  my %pairs;

  my $methods = $self->meta->column_accessor_method_names_hash;

  while(my($column, $method) = each(%$methods))
  {
    $pairs{$column} = $self->$method();
  }

  return wantarray ? %pairs : \%pairs;
}

sub column_accessor_value_pairs
{
  my($self) = shift;

  my %pairs;

  foreach my $method ($self->meta->column_accessor_method_names)
  {
    $pairs{$method} = $self->$method();
  }

  return wantarray ? %pairs : \%pairs;
}

sub column_mutator_value_pairs
{
  my($self) = shift;

  my %pairs;

  foreach my $column ($self->meta->columns)
  {
    my $method = $column->accessor_method_name;
    $pairs{$column->mutator_method_name} = $self->$method();
  }

  return wantarray ? %pairs : \%pairs;
}

sub clone
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  return $class->new(map { $_ => $self->$_() } $self->meta->column_accessor_method_names);
}

sub clone_and_reset
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  my $clone = $class->new(map { $_ => $self->$_() } $self->meta->column_accessor_method_names);

  my $meta = $class->meta;

  no strict 'refs';

  # Blank all primary and unique key columns
  foreach my $method ($meta->primary_key_column_mutator_names)
  {
    $clone->$method(undef);
  }

  foreach my $uk ($meta->unique_keys)
  {
    foreach my $column ($uk->columns)
    {
      my $method = $meta->column_mutator_method_name($column);
      $clone->$method(undef);
    }
  }

  # Also copy db object, if any
  if(my $db = $self->{'db'})
  {
    #$self->{FLAG_DB_IS_PRIVATE()} = 0;
    $clone->db($db);
  }

  return $clone;
}

sub has_loaded_related
{
  my($self) = shift;

  my $rel; # really a relationship or fk

  my $meta = $self->meta;

  if(@_ == 1)
  {
    my $name = shift;

    if($rel = $meta->foreign_key($name))
    {
      return $rel->object_has_foreign_object($self) ? 1 : 0;
    }
    elsif($rel = $meta->relationship($name))
    {
      return $rel->object_has_related_objects($self) ? 1 : 0;
    }
    else
    {
      croak "No foreign key or relationship named '$name' found in ",
            $meta->class;
    }
  }
  else
  {
    my %args = @_;
    my $name;

    if($name = $args{'foreign_key'})
    {
      $rel = $meta->foreign_key($name) 
        or croak "No foreign key named '$name' found in ", $meta->class;

      return $rel->object_has_foreign_object($self) ? 1 : 0;
    }
    elsif($name = $args{'relationship'})
    {
      $rel = $meta->relationship($name) 
        or croak "No relationship named '$name' found in ", $meta->class;

      return $rel->object_has_related_objects($self) ? 1 : 0;
    }
    else
    {
      croak "Missing foreign key or relationship name argument";
    }
  }
}

1;

__END__

=head1 NAME

Rose::DB::Object::Helpers - A mix-in class containing convenience methods for Rose::DB::Object.

=head1 SYNOPSIS

  package MyDBObject;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  use Rose::DB::Object::Helpers 'clone', 
    { load_or_insert => 'find_or_create' };
  ...

  $obj = MyDBObject->new(id => 123);
  $obj->find_or_create();

  $obj2 = $obj->clone;

=head1 DESCRIPTION

L<Rose::DB::Object::Helpers> provides convenience methods from use with L<Rose::DB::Object>-derived classes.  These methods do not exist in L<Rose::DB::Object> in order to keep the method namespace clean.  (Each method added to L<Rose::DB::Object> is another potential naming conflict with a column accessor.)

This class inherits from L<Rose::DB::Object::MixIn>.  See the L<Rose::DB::Object::MixIn> documentation for a full explanation of how to import methods from this class.  The helper methods themselves are described below.

=head1 OBJECT METHODS

=over 4

=item B<clone>

Returns a new object initialized with the column values of the existing object.  For example, imagine a C<Person> class with three columns, C<id>, C<name>, and C<age>.

    $a = Person->new(id => 123, name => 'John', age => 30);

This use of the C<clone()> method:

    $b = $a->clone;

is equivalent to this:

    $b = Person->new(id => $a->id, name => $a->name, age => $a->age);

=item B<clone_and_reset>

This is the same as the L<clone|/clone> method described above, except that it also sets all of the L<primary|Rose::DB::Object::Metadata/primary_key_columns> and L<unique key columns|Rose::DB::Object::Metadata/unique_keys> to undef.  If the cloned object has a L<db|Rose::DB::Object/db> attribute, then it is copied to the clone object as well.

For example, imagine a C<Person> class with three columns, C<id>, C<name>, and C<age>, where C<id> is the primary key and C<name> is a unique key.

    $a = Person->new(id => 123, name => 'John', age => 30, db => $db);

This use of the C<clone_and_reset()> method:

    $b = $a->clone_and_reset;

is equivalent to this:

    $b = Person->new(id => $a->id, name => $a->name, age => $a->age);
    $b->id(undef);   # reset primary key
    $b->name(undef); # reset unique key
    $b->db($a->db);  # copy db

=item B<column_values_as_json>

Returns a string containing a JSON representation of the object's column values.  You must have the L<JSON::Syck> module installed in order to use this helper method.

=item B<column_values_as_yaml>

Returns a string containing a YAML representation of the object's column values.  You must have the L<YAML::Syck> module installed in order to use this helper method.

=item B<column_accessor_value_pairs>

Returns a hash (in list context) or reference to a hash (in scalar context) of column accessor method names and column values.  The keys of the hash are the L<accessor method names|Rose::DB::Object::Metadata::Column/accessor_method_name> for the columns.  The values are retrieved by calling the L<accessor method|Rose::DB::Object::Metadata::Column/accessor_method_name> for each column.

=item B<column_mutator_value_pairs>

Returns a hash (in list context) or reference to a hash (in scalar context) of column mutator method names and column values.  The keys of the hash are the L<mutator method names|Rose::DB::Object::Metadata::Column/mutator_method_name> for the columns.  The values are retrieved by calling the L<accessor method|Rose::DB::Object::Metadata::Column/accessor_method_name> for each column.

=item B<column_value_pairs>

Returns a hash (in list context) or reference to a hash (in scalar context) of column name and value pairs.  The keys of the hash are the L<names|Rose::DB::Object::Metadata::Column/name> of the columns.  The values are retrieved by calling the L<accessor method|Rose::DB::Object::Metadata::Column/accessor_method_name> for each column.

=item B<has_loaded_related [ NAME | PARAMS ]>

Given a foreign key or relationship name, return true if one or more related objects have been loaded into the current object, false otherwise.

If the name is passed as a plain string NAME, then a foreign key with that name is looked up.  If no such foreign key exists, then a relationship with that name is looked up.  If no such relationship or foreign key exists, a fatal error will occur.  Example:

    $foo->has_loaded_related('bar');

It's generally not a good idea to add a foreign key and a relationship with the same name, but it is technically possible.  To specify the domain of the name, pass the name as the value of a C<foreign_key> or C<relationship> parameter.  Example:

    $foo->has_loaded_related(foreign_key => 'bar');
    $foo->has_loaded_related(relationship => 'bar');

=item B<init_with_column_value_pairs [ HASH | HASHREF ]>

Initialize an object with a hash or reference to a hash of column/value pairs.  This differs from the inherited L<init|Rose::Object/init> method in that it accepts column names rather than method names.  A column name may not be the same as its mutator method name if the column is L<aliased|Rose::DB::Object::Metadata/alias_column>, for example.

    $p = Person->new; # assume "type" column is aliased to "person_type"

    # init() takes method/value pairs
    $p->init(person_type => 'cool', age => 30);

    # Helper takes a hashref of column/value pairs
    $p->init_with_column_value_pairs({ type => 'cool', age => 30 });

    # ...or a hash of column/value pairs
    $p->init_with_column_value_pairs(type => 'cool', age => 30);

=item B<init_with_json JSON>

Initialize the object with a JSON-formatted string.  The JSON string must be in the format returned by the L<column_values_as_json|/column_values_as_json> method.  Example:

    $p1 = Person->new(name => 'John', age => 30);
    $json = $p1->column_values_as_json;

    $p2 = Person->new;
    $p2->init_with_json($json);

    print $p2->name; # John
    print $p2->age;  # 30

=item B<init_with_yaml YAML>

Initialize the object with a YAML-formatted string.  The YAML string must be in the format returned by the L<column_values_as_yaml|/column_values_as_yaml> method.  Example:

    $p1 = Person->new(name => 'John', age => 30);
    $yaml = $p1->column_values_as_yaml;

    $p2 = Person->new;
    $p2->init_with_yaml($yaml);

    print $p2->name; # John
    print $p2->age;  # 30

=item B<insert_or_update [PARAMS]>

If the object already exists in the database, then L<update|Rose::DB::Object/update> it.  Otherwise, L<insert|Rose::DB::Object/insert> it.  Any PARAMS are passed on to the calls to L<insert|Rose::DB::Object/insert> or L<update|Rose::DB::Object/update>.

This method differs from the standard L<save|Rose::DB::Object/save> method in that L<save|Rose::DB::Object/save> decides to L<insert|Rose::DB::Object/insert> or L<update|Rose::DB::Object/update> based solely on whether or not the object was previously L<load|Rose::DB::Object/load>ed.  This method will take the extra step of actually attempting to L<load|Rose::DB::Object/load> the object to see whether or not it's in the database.

The return value of the L<insert|Rose::DB::Object/insert> or L<update|Rose::DB::Object/update> method (whichever is called) is returned.

=item B<insert_or_update_on_duplicate_key [PARAMS]>

Update or insert a row with a single SQL statement, depending on whether or not a row with the same primary or unique key already exists.  Any PARAMS are passed on to the call to L<insert|Rose::DB::Object/insert> or L<update|Rose::DB::Object/update>.

If the current database does not support the "ON DUPLICATE KEY UPDATE" SQL extension, then this method simply call the L<insert_or_update|/insert_or_update> method, pasing all PARAMS.

Currently, the only database that supports "ON DUPLICATE KEY UPDATE" is MySQL, and only in version 4.1.0 or later.  You can read more about the feature here:

L<http://dev.mysql.com/doc/refman/5.1/en/insert-on-duplicate.html>

Here's a quick example of the SQL syntax:

    INSERT INTO table (a, b, c) VALUES (1, 2, 3) 
      ON DUPLICATE KEY UPDATE a = 1, b = 2, c = 3;

Note that there are two sets of columns and values in the statement.  This presents a choice: which columns to put in the "INSERT" part, and which to put in the "UPDATE" part.

When using this method, if the object was previously L<load|Rose::DB::Object/load>ed from the database, then values for all columns are put in both the "INSERT" and "UPDATE" portions of the statement.

Otherwise, all columns are included in both clauses I<except> those belonging to primary keys or unique keys which have only undefined values.  This is important because it allows objects to be updated based on a single primary or unique key, even if other possible keys exist, but do not have values set.  For example, consider this table with the following data:

    CREATE TABLE parts
    (
      id      INT PRIMARY KEY,
      code    CHAR(3) NOT NULL,
      status  CHAR(1),

      UNIQUE(code)
    );

    INSERT INTO parts (id, code, status) VALUES (1, 'abc', 'x');

This code will update part id 1, setting its "status" column to "y".

    $p = Part->new(code => 'abc', status => 'y');
    $p->insert_or_update_on_duplicate_key;

The resulting SQL:

    INSERT INTO parts (code, status) VALUES ('abc', 'y') 
      ON DUPLICATE KEY UPDATE code = 'abc', status = 'y';

Note that the "id" column is omitted because it has an undefined value.  The SQL statement will detect the duplicate value for the unique key "code" and then run the "UPDATE" portion of the query, setting "status" to "y".

This method returns true if the row was inserted or updated successfully, false otherwise.  The true value returned on success will be the object itself.  If the object L<overload>s its boolean value such that it is not true, then a true value will be returned instead of the object itself.

Yes, this method name is very long.  Remember that you can rename methods on import.  It is expected that most people will want to rename this method to "insert_or_update", using it in place of the normal L<insert_or_update|/insert_or_update> helper method:

    package My::DB::Object;
    ...
    use Rose::DB::Object::Helpers 
      { insert_or_update_on_duplicate_key => 'insert_or_update' };

=item B<load_or_insert [PARAMS]>

Try to L<load|Rose::DB::Object/load> the object, passing PARAMS to the call to the L<load()|Rose::DB::Object/load> method.  The parameter "speculative => 1" is automatically added to PARAMS.  If no such object is found, then the object is L<inserted|Rose::DB::Object/insert>.

Example:

    # Get object id 123 if it exists, otherwise create it now.
    $obj = MyDBObject->new(id => 123)->load_or_insert;

=item B<load_speculative [PARAMS]>

Try to L<load|Rose::DB::Object/load> the object, passing PARAMS to the call to the L<load()|Rose::DB::Object/load> method along with the "speculative => 1" parameter.  See the documentation for L<Rose::DB::Object>'s L<load|Rose::DB::Object/load> method for more information.

Example:

    $obj = MyDBObject->new(id => 123);

    if($obj->load_speculative)
    {
      print "Found object id 123\n";
    }
    else
    {
      print "Object id 123 not found\n";
    }

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
