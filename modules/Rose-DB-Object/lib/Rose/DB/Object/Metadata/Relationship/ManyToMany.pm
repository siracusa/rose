package Rose::DB::Object::Metadata::Relationship::ManyToMany;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.021';

__PACKAGE__->default_auto_method_types('get');

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
    __PACKAGE__->common_method_maker_argument_names
  ],
);

__PACKAGE__->method_maker_info
(
  get =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'objects_by_map',
  },
);

sub type { 'many to many' }

sub build_method_name_for_type
{
  my($self, $type) = @_;

  if($type eq 'get')
  {
    return $self->name;
  }

  return undef;
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

There's a bit of a "chicken and egg" problem here in that all these classes need to know about each other more or less "simultaneously," but they must be defined in a serial fashion, and may be loaded in any order by the user.

The simplest way to handle this is to put the setup information for all the classes into a single ".pm" file: C<WidgetSetup.pm>.  Then have the other files (C<Widget.pm>, C<Color.pm> and C<WidgetColorMap.pm>) simply C<require> or C<use> the setup file.

In fact, this is the only reasonable way to create this set of classes with I<all> of the relationships defined in such a way that module load order does not matter.  If you are willing to forgo this constraint or leave some of the relationships unspecified, then other solutions are possible.

Anyway, here's the code.  First, the C<WidgetSetup.pm> file.

  package WidgetSetup;

  use strict;

  # Set up the column and table information for all three classes that
  # participate in the "many to many" widgets/colors relationship.

  package Widget;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  Widget->meta->table('widgets');
  Widget->meta->columns
  (
    id   => { type => 'int', primary_key => 1 },
    name => { type => 'varchar', length => 255 },
  );

  package Color;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  Color->meta->table('colors');
  Color->meta->columns
  (
    id   => { type => 'int', primary_key => 1 },
    name => { type => 'varchar', length => 255 },
  );

  package WidgetColorMap;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  WidgetColorMap->meta->table('widget_color_map');
  WidgetColorMap->meta->columns
  (
    id        => { type => 'int', primary_key => 1 },
    widget_id => { type => 'int' },
    color_id  => { type => 'int' },
  );

  #
  # Set up WidgetColorMap's foreign keys and initialize the class
  #

  WidgetColorMap->meta->foreign_keys
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

  WidgetColorMap->meta->initialize;

  #
  # Set up the relationships in the Widget and Color classes
  #

  Widget->meta->add_relationship
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

  Color->meta->add_relationship
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

  #
  # Finally, initialize the Widget and Color classes
  #

  Color->meta->initialize;
  Widget->meta->initialize;

  1;

Note that the order of the steps in the code above is important.  The key "trick" demonstrated is defining enough of the C<Color> and C<Widget> classes for the C<WidgetColorMap> class to have what it needs to initialize itself, and then delaying the C<Widget> and C<Color> "many to many" relationship definitions and initializations until after C<WidgetColorMap> is completely configured.

The individual class files are now very simple.  WidgetColorMap.pm:

  package WidgetColorMap;

  use WidgetSetup;

  1;

Widget.pm:

  package Widget;

  use WidgetSetup;

  1;

Color.pm:

  package Color;

  use WidgetSetup;

  sub bizarro_name { scalar reverse shift->name }

  1;

Note that only the table, column, and relationship setup has to go in WidgetSetup.pm.  Other methods are free to go in their "normal" locations, as shown with the C<bizarro_name()> method in the C<Color> class.

Finally, here's an initial set of data and some examples of the classes in action.  First, the data:

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

Phew.  It's actually not as complex as it seems, although there is something to be said for manually creating the C<colors()> and C<widgets()> methods.  If you look to see what's being done on your behalf behind the scenes, it's actually not that complex.  Most of the work involves determining which columns of which tables point to which columns in which other tables.  You, the programmer, already know this information, so manual "many to many" method definitions are usually straightforward.

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

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<objects_by_map|Rose::DB::Object::MakeMethods::Generic/objects_by_map>, ...

=back

See the L<Rose::DB::Object::Metadata::Relationship|Rose::DB::Object::Metadata::Relationship/"MAKING METHODS"> documentation for an explanation of this method map.


=head1 OBJECT METHODS

=over 4

=item B<build_method_name_for_type TYPE>

Return a method name for the relationship method type TYPE.  Returns the relationship's L<name|Rose::DB::Object::Metadata::Relationship/name> for the method type "get", undef otherwise.

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
      manager_args => { sort_by => 'name' },
    },
  );

This would ensure that a C<Widget>'s C<colors()> are listed in alphabetical order.  See the documentation for L<Rose::DB::Object::Manager>'s L<get_objects|Rose::DB::Object::Manager/get_objects> method for a full list of valid arguments, but remember that you can define your own custom L<manager_class> and thus can also define what kinds of arguments it takes.

=item B<map_class [CLASS]>

Get or set the name of the L<Rose::DB::Object>-derived class that fronts the table that maps between the other two tables.  This class must have a foreign key and/or "one to one" relationship for each of the two tables that it maps between.

In the L<example|EXAMPLE> above, the map class is C<WidgetColorMap>.

=item B<map_from [NAME]>

Get or set the name of the "one to one" relationship or foreign key in L<map_class|/map_class> that points to the object of the current class.  Setting this value is only necessary if the L<map class|/map_class> has more than one foreign key or "one to one" relationship that points to one of the classes that it maps between.

In the L<example|EXAMPLE> above, the value of L<map_from|/map_from> would be "widget" when defining the "many to many" relationship in the C<Widget> class, or "color" when defining the "many to many" relationship in the C<Color> class.  Neither of these settings is necessary in the example because the C<WidgetColorMap> class has one foreign key that points to each class, so there is no ambiguity.

=item B<map_to [NAME]>

Get or set the name of the "one to one" relationship or foreign key in L<map_class|/map_class> that points to the "foreign" object to be fetched.  Setting this value is only necessary if the L<map class|/map_class> has more than one foreign key or "one to one" relationship that points to one of the classes that it maps between.

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
