package Rose::DB::Object::Metadata::Relationship::ManyToMany;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.023';

__PACKAGE__->default_auto_method_types('get_set');

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(share_db map_class map_from map_to manager_class manager_method
     manager_args query_args)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    'share_db' => { default => 1 },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    __PACKAGE__->common_method_maker_argument_names,
  ],

  # These are set by the method maker when make_methods() is called

  scalar => 
  [
    'foreign_class', # class to be fetched
  ],

  hash =>
  [
    # Map from local columns to foreign columns
    'column_map',
  ]
);

__PACKAGE__->method_maker_info
(
  get_set =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'objects_by_map',
  },
);

sub type { 'many to many' }

sub build_method_name_for_type
{
  my($self, $type) = @_;

  if($type eq 'get_set')
  {
    return $self->name;
  }

  return undef;
}

sub sanity_check
{
  my($self) = shift;

  defined $self->map_class or 
    Carp::croak $self->type, " relationship '", $self->name,
                "' is missing a map_class";

  return 1;
}

sub is_ready_to_make_methods
{
  my($self) = shift;

  eval
  {
    my $map_class = $self->map_class or die "Missing map class";
    my $map_meta  = $map_class->meta or die "Missing map class meta";
    my $map_from  = $self->map_from;
    my $map_to    = $self->map_to;

    my $target_class = $self->parent->class;
    my $meta         = $target_class->meta;
    my $map_to_method;

    # Build the map of "local" column names to "foreign" object method names. 
    # The words "local" and "foreign" are relative to the *mapper* class.
    my %key_template;

    # Also grab the foreign object class that the mapper points to,
    # the relationship name that points back to us, and the class 
    # name of the objects we really want to fetch.
    my($with_objects, $local_rel, $foreign_class, %seen_fk);

    foreach my $item ($map_meta->foreign_keys, $map_meta->relationships)
    {
      # Track which foreign keys we've seen
      if($item->isa('Rose::DB::Object::Metadata::ForeignKey'))
      {
        $seen_fk{$item->id}++;
      }
      elsif($item->isa('Rose::DB::Object::Metadata::Relationship'))
      {
        # Skip a relationship if we've already seen the equivalent foreign key
        next  if($seen_fk{$item->id});
      }

      if($item->class eq $target_class)
      {
        # Skip if there was an explicit local relationship name and
        # this is not that name.
        next  if($map_from && $item->name ne $map_from);

        if(%key_template)
        {
          die "Map class $map_class has more than one foreign key ",
              "and/or 'many to one' relationship that points to the ",
              "class $target_class.  Please specify one by name ",
              "with a 'local' parameter in the 'map' hash";
        }

        $local_rel = $item->name;

        my $map_columns = 
          $item->can('column_map') ? $item->column_map : $item->key_columns;

        # "local" and "foreign" here are relative to the *mapper* class
        while(my($local_column, $foreign_column) = each(%$map_columns))
        {
          my $foreign_method = $meta->column_accessor_method_name($foreign_column)
            or Carp::croak "Missing accessor method for column '$foreign_column'", 
                           " in class ", $meta->class;
          $key_template{$local_column} = $foreign_method;
        }
      }
      elsif($item->isa('Rose::DB::Object::Metadata::ForeignKey') ||
            $item->type eq 'many to one')
      {
        # Skip if there was an explicit foreign relationship name and
        # this is not that name.
        next  if($map_to && $item->name ne $map_to);

        if($with_objects)
        {
          Carp::croak "Map class $map_class has more than one foreign key ",
                      "and/or 'many to one' relationship that points to a ",
                      "class other than $target_class.  Please specify one ",
                      "by name with a 'foreign' parameter in the 'map' hash";
        }

        $with_objects  = [ $item->name ];
        $foreign_class = $item->class;
        $map_to_method = $item->method_name('get_set');
      }
    }

    unless(%key_template)
    {
      die "Could not find a foreign key or 'many to one' relationship ",
          "in $map_class that points to $target_class";
    }

    unless($with_objects)
    {
      # Make a second attempt to find a a suitable foreign relationship in the
      # map class, this time looking for links back to $target_class so long as
      # it's a different relationship than the one used in the local link.
      foreach my $item ($map_meta->foreign_keys, $map_meta->relationships)
      {
        # Skip a relationship if we've already seen the equivalent foreign key
        if($item->isa('Rose::DB::Object::Metadata::Relationship'))
        {
          next  if($seen_fk{$item->id});
        }

        if(($item->isa('Rose::DB::Object::Metadata::ForeignKey') ||
           $item->type eq 'many to one') &&
           $item->class eq $target_class && $item->name ne $local_rel)
        {  
          if($with_objects)
          {
            die "Map class $map_class has more than two foreign keys ",
                "and/or 'many to one' relationships that points to a ",
                "$target_class.  Please specify which ones to use ",
                "by including 'local' and 'foreign' parameters in the ",
                "'map' hash";
          }

          $with_objects = [ $item->name ];
          $foreign_class = $item->class;
          $map_to_method = $item->method_name('get_set');
        }
      }
    }

    unless($with_objects)
    {
      die "Could not find a foreign key or 'many to one' relationship ",
          "in $map_class that points to a class other than $target_class"
    }
  };

  return $@ ? 0 : 1;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship::ManyToMany - One to many table relationship metadata object.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Relationship::ManyToMany;

  $rel = Rose::DB::Object::Metadata::Relationship::ManyToMany->new(...);
  $rel->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for relationships in which rows from one table are connected to rows in another table through an intermediate table that maps between them. 

This class inherits from L<Rose::DB::Object::Metadata::Relationship>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Relationship> documentation for more information.

=head1 EXAMPLE

Consider the following tables.

    CREATE TABLE widgets
    (
      id    SERIAL PRIMARY KEY,
      name  VARCHAR(255)
    );

    CREATE TABLE colors
    (
      id    SERIAL PRIMARY KEY,
      name  VARCHAR(255)
    );

    CREATE TABLE widget_color_map
    (
      id         SERIAL PRIMARY KEY,
      widget_id  INT NOT NULL REFERENCES widgets (id),
      color_id   INT NOT NULL REFERENCES colors (id),
      UNIQUE(widget_id, color_id)
    );

Given these tables, each widget can have zero or more colors, and each color can be applied to zero or more widgets.  This is the type of "many to many" relationship that this class is designed to handle.

In order to do so, each of the three of the tables that participate in the relationship must be fronted by its own L<Rose::DB::Object>-derived class.  Let's call those classes C<Widget>, C<Color>, and C<WidgetColorMap>.

The class that maps between the other two classes is called the "L<map class|/map_class>."  In this example, it's C<WidgetColorMap>.  The map class B<must> have a foreign key and/or "many to one" relationship pointing to each of the two classes that it maps between.

When it comes to actually creating the three classes that participate in a "many to many" relationship, there's a bit of a "chicken and egg" problem.  All these classes need to know about each other more or less "simultaneously," but they must be defined in a serial fashion, and may be loaded in any order by the user.

In order to account for this, method creation may be deferred for any foreign key or relationship that does not yet have all the information it requires to do its job.  This should be transparent to the developer, provided that following guidelines are obeyed:

=over 4

=item * The L<map class|/map_class> should C<use> both of the classes that it maps between.

=item * The other two classes should C<use> the L<map class|/map_class>.

=back

Here's a complete example using the C<Widget>, C<Color>, and C<WidgetColorMap> classes.  First, the C<Widget> class which has a "many to many" relationship through which it can retrieve its colors.  The C<Widget> class needs to load the map class, C<WidgetColorMap>.

  package Widget;

  use WidgetColorMap; # load map class

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('widgets');
  __PACKAGE__->meta->columns
  (
    id   => { type => 'int', primary_key => 1 },
    name => { type => 'varchar', length => 255 },
  );

  # Define "many to many" relationship to get colors
  __PACKAGE__->meta->add_relationship
  (
    colors =>
    {
      type      => 'many to many',
      map_class => 'WidgetColorMap',

      # These are only necessary if the relationship is ambiguous
      #map_from  => 'widget',
      #map_to    => 'color',
    },
  );

  __PACKAGE__->meta->initialize;

  1;

Next, the C<Color> class which has a "many to many" relationship through which it can retrieve all the widgets that have this color.  The C<Color> class also needs to load the map class, C<WidgetColorMap>.

  package Color;

  use WidgetColorMap; # load map class

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('colors');
  __PACKAGE__->meta->columns
  (
    id   => { type => 'int', primary_key => 1 },
    name => { type => 'varchar', length => 255 },
  );

  # Define "many to many" relationship to get widgets
  __PACKAGE__->meta->add_relationship
  (
    widgets =>
    {
      type      => 'many to many',
      map_class => 'WidgetColorMap',

      # These are only necessary if the relationship is ambiguous
      #map_from  => 'color',
      #map_to    => 'widget',
    },
  );

  __PACKAGE__->meta->initialize;

  1;

Finally, the C<WidgetColorMap> class which must load both of the classes that it maps between (C<Widget> and C<Color>) and must have a foreign key or "many to one" relationship that points to each of them.

  package WidgetColorMap;

  # Load both classes that this class maps between
  use Widget;
  use Color;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('widget_color_map');
  __PACKAGE__->meta->columns
  (
    id        => { type => 'int', primary_key => 1 },
    widget_id => { type => 'int' },
    color_id  => { type => 'int' },
  );

  # Define foreign keys that point to each of the two classes 
  # that this class maps between.
  __PACKAGE__->meta->foreign_keys
  (
    color => 
    {
      class => 'Color',
      key_columns => { color_id => 'id' },
    },

    widget => 
    {
      class => 'Widget',
      key_columns => { widget_id => 'id' },
    },  
  );

  __PACKAGE__->meta->initialize;

  1;

Here's an initial set of data and some examples of the above classes in action.  First, the data:

  INSERT INTO widgets (id, name) VALUES (1, 'Sprocket');
  INSERT INTO widgets (id, name) VALUES (2, 'Flange');

  INSERT INTO colors (id, name) VALUES (1, 'Red');
  INSERT INTO colors (id, name) VALUES (2, 'Green');
  INSERT INTO colors (id, name) VALUES (3, 'Blue');

  INSERT INTO widget_color_map (widget_id, color_id) VALUES (1, 1);
  INSERT INTO widget_color_map (widget_id, color_id) VALUES (1, 2);
  INSERT INTO widget_color_map (widget_id, color_id) VALUES (2, 3);

Now the code:

  use Widget;
  use Color;

  $widget = Widget->new(id => 1);
  $widget->load;

  @colors = map { $_->name } $widget->colors; # ('Red', 'Green')

  $color = Color->new(id => 1);
  $color->load;

  @widgets = map { $_->name } $c->widgets; # ('Sprocket')

Phew!  It's actually not as complex as it seems.  On the other hand, there is something to be said for manually creating the C<colors()> and C<widgets()> methods.  If you look to see what's being done on your behalf behind the scenes, it's actually not that complex.  Most of the work involves determining which columns of which tables point to which columns in which other tables.  You, the programmer, already know this information, so manual "many to many" method definitions are usually straightforward.

For example, here's a custom implementation of the C<Widget> class's C<colors()> method:

  package Widget;
  ...
  use WidgetColorMap;
  use Rose::DB::Object::Manager;
  ...

  sub colors
  {
    my $self = shift;

    my $map_records = 
      Rose::DB::Object::Manager->get_objects(
        object_class => 'WidgetColorMap',
        with_objects => [ 'color' ],
        query =>
        [
          widget_id => $self->id
        ]);

    my @colors = map { $_->color } @$map_records;

    return wantarray ? @colors : \@colors;
  }

You might notice that that's actually about the same amount of typing as what's required to setup all the relationships to take advantage of the automatic method generation.  On the other hand, the relationship definitions provide a central location for this information, which might aid in maintenance.

In the end, it's up to you.  Which technique makes more sense in terms of initial effort and ongoing ease of maintenance is a question you'll have to answer yourself.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<objects_by_map|Rose::DB::Object::MakeMethods::Generic/objects_by_map>, ...

=back

See the L<Rose::DB::Object::Metadata::Relationship|Rose::DB::Object::Metadata::Relationship/"MAKING METHODS"> documentation for an explanation of this method map.


=head1 OBJECT METHODS

=over 4

=item B<build_method_name_for_type TYPE>

Return a method name for the relationship method type TYPE.  Returns the relationship's L<name|Rose::DB::Object::Metadata::Relationship/name> for the method type "get_set", undef otherwise.

=item B<manager_class [CLASS]>

Get or set the name of the L<Rose::DB::Object::Manager>-derived class that the L<map_class|/map_class> will use to fetch records.  The L<make_methods|Rose::DB::Object::Metadata::Relationship/make_methods> method will use L<Rose::DB::Object::Manager> if this value is left undefined.

=item B<manager_method [METHOD]>

Get or set the name of the L<manager_class|/manager_class> class method to call when fetching records.  The L<make_methods|Rose::DB::Object::Metadata::Relationship/make_methods> method will use L<get_objects|Rose::DB::Object::Manager/get_objects> if this value is left undefined.

=item B<manager_args [HASHREF]>

Get or set a reference to a hash of name/value arguments to pass to the L<manager_method|/manager_method> when fetching objects.  For example, this can be used to enforce a particular sort order for objects fetched via this relationship.  Modifying the L<example|/EXAMPLE> above:

  Widget->meta->add_relationship
  (
    colors =>
    {
      type         => 'many to many',
      map_class    => 'WidgetColorMap',
      manager_args => { sort_by => Color->meta->table . '.name' },
    },
  );

This would ensure that a C<Widget>'s C<colors()> are listed in alphabetical order.  Note that the "name" column is prefixed by the name of the table fronted by the C<Color> class.  This is important because several tables may have a column named "name."  If this relationship is used to form a JOIN in a query along with one of those tables, then the "name" column will be ambiguous.  Adding a table name prefix disambiguates the column name.

Also note that the table name is not hard-coded.  Instead, it is fetched from the L<Rose::DB::Object>-derived class that fronts the table.  This is more verbose, but is a much better choice than including the literal table name when it comes to long-term maintenance of the code.

See the documentation for L<Rose::DB::Object::Manager>'s L<get_objects|Rose::DB::Object::Manager/get_objects> method for a full list of valid arguments for use with the C<manager_args> parameter, but remember that you can define your own custom L<manager_class> and thus can also define what kinds of arguments C<manager_args> will accept.

=item B<map_class [CLASS]>

Get or set the name of the L<Rose::DB::Object>-derived class that fronts the table that maps between the other two tables.  This class must have a foreign key and/or "many to one" relationship for each of the two tables that it maps between.

In the L<example|EXAMPLE> above, the map class is C<WidgetColorMap>.

=item B<map_from [NAME]>

Get or set the name of the "many to one" relationship or foreign key in L<map_class|/map_class> that points to the object of the current class.  Setting this value is only necessary if the L<map class|/map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

In the L<example|EXAMPLE> above, the value of L<map_from|/map_from> would be "widget" when defining the "many to many" relationship in the C<Widget> class, or "color" when defining the "many to many" relationship in the C<Color> class.  Neither of these settings is necessary in the example because the C<WidgetColorMap> class has one foreign key that points to each class, so there is no ambiguity.

=item B<map_to [NAME]>

Get or set the name of the "many to one" relationship or foreign key in L<map_class|/map_class> that points to the "foreign" object to be fetched.  Setting this value is only necessary if the L<map class|/map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

In the L<example|EXAMPLE> above, the value of L<map_from> would be "color" when defining the "many to many" relationship in the C<Widget> class, or "widget" when defining the "many to many" relationship in the C<Color> class.  Neither of these settings is necessary in the example because the C<WidgetColorMap> class has one foreign key that points to each class, so there is no ambiguity.

=item B<query_args [HASHREF]>

Get or set a reference to a hash of name/value arguments to add to the L<query|Rose::DB::Object::Manager/query> argument to the L<manager_method|/manager_method> when fetching objects.

This can be used to limit the objects fetched via this relationship.  For example, modifying the L<example|/EXAMPLE> above:

  Widget->meta->add_relationship
  (
    colors =>
    {
      type       => 'many to many',
      map_class  => 'WidgetColorMap',
      query_args => { name => { like => '%e%' } },
    },
  );

This would ensure that a C<Widget>'s C<colors()> would be limited to those that contain the letter "e".  See the documentation for L<Rose::DB::Object::Manager>'s L<get_objects|Rose::DB::Object::Manager/get_objects> method for a full list of valid C<query> arguments, but remember that you can define your own custom L<manager_class> and thus can also define what kinds of query arguments it takes.

=item B<share_db [BOOL]>

Get or set a boolean flag that indicates whether or not all of the classes involved in fetching objects via this relationship (including the objects themselves) will share the same L<Rose::DB>-derived L<db|Rose::DB::Object/db> object.  Defaults to true.

=item B<type>

Returns "many to many".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
