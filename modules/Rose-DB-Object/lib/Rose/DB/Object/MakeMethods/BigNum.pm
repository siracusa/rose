package Rose::DB::Object::MakeMethods::BigNum;

use strict;

use Carp();

use Math::BigInt lib => 'GMP';

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

our $VERSION = '0.70';

our $Debug = 0;

sub bigint
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $default   = $args->{'default'};
  my $check_in  = $args->{'check_in'};
  my $min       = $args->{'min'};
  my $max       = $args->{'min'};

  my $init_method;

  if(exists $args->{'with_init'} || exists $args->{'init_method'})
  {
    $init_method = $args->{'init_method'} || "init_$name";
  }

  ##
  ## Build code snippets
  ##

  my $qkey = $key;
  $qkey =~ s/'/\\'/g;
  my $qname = $name;
  $qname =~ s/"/\\"/g;

  #
  # check_in code
  #

  my $check_in_code = '';
  my %check;

  if($check_in)
  {
    $check_in = [ $check_in ] unless(ref $check_in);
    %check = map { $_ => 1 } @$check_in;

    $check_in_code=<<"EOF";
if(defined \$value)
    {
      Carp::croak "Invalid $name: '\$value'"  unless(exists \$check{\$value});
    }

EOF
  }

  #
  # min/max code
  #

  my $min_max_code = '';

  if($min)
  {
    unless($min =~ /^-?\d+$/)
    {
      Carp::croak "Invalid minimum value for bigint column $qname: '$min'";
    }

    $min_max_code =<<"EOF";
no warnings 'uninitialized';
    if(\$value < $min)
    {
      Carp::croak ref(\$self), ": Value \$value for $qname() is too small.  ",
                  "It must be greater than or equal to $min.";
    }
EOF
  }

  if($max)
  {
    unless($max =~ /^-?\d+$/)
    {
      Carp::croak "Invalid maximum value for bigint column $qname: '$max'";
    }

    $min_max_code =<<"EOF";
no warnings 'uninitialized';
    if(\$value < $min)
    {
      Carp::croak ref(\$self), ": Value \$value for $qname() is too large.  ",
                  "It must be less than or equal to $max.";
    }
EOF
  }

  #
  # set code
  #

  my $set_code = qq(\$self->{'$qkey'} = Math::BigInt->new(\$value););

  #
  # return code
  #

  my($return_code, $return_code_shift);

  if(defined $default)
  {
    $default = Math::BigInt->new($default);

    $return_code=<<"EOF";
return (defined \$self->{'$qkey'}) ? \$self->{'$qkey'} : 
       (\$self->{'$qkey'} = \$default);
EOF
  }
  elsif(defined $init_method)
  {
    $return_code=<<"EOF";
return (defined \$self->{'$qkey'}) ? \$self->{'$qkey'} : 
       (\$self->{'$qkey'} = Math::BigInt->new(\$self->$init_method()));
EOF
  }
  else
  {
    $return_code       = qq(return \$self->{'$qkey'};);
    $return_code_shift = qq(return shift->{'$qkey'};);
  }

  $return_code_shift ||= $return_code;

  my %methods;

  if($interface eq 'get_set')
  {
    my $code;

    # I can't help myself...
    if(defined $default || defined $init_method)
    {
      $code=<<"EOF";
sub
{
  my \$self = shift;

  if(\@_)
  {
    my \$value = shift;

    $check_in_code
    $min_max_code
    $set_code
    $return_code
  }

  $return_code
};
EOF
    }
    else
    {
      $code=<<"EOF";
sub
{
  if(\@_ > 1)
  {
    my \$self  = shift;
    my \$value = shift;

    $check_in_code
    $min_max_code
    return $set_code
  }

  $return_code_shift
};
EOF
    }

    $Debug && warn "sub $name = ", $code;
    $methods{$name} = eval $code;

    if($@)
    {
      Carp::croak "Error in generated code for method $name - $@\n",
                  "Code was: $code";
    }
  }
  elsif($interface eq 'get')
  {
    my $code;

    # I can't help myself...
    if(defined $default || defined $init_method)
    {
      $code = qq(sub { my \$self = shift; $return_code };);
    }
    else
    {
      $code = qq(sub { shift->{'$qkey'} });
    }

    $Debug && warn "sub $name = ", $code;
    $methods{$name} = eval $code;

    if($@)
    {
      Carp::croak "Error in generated code for method $name - $@\n",
                  "Code was: $code";
    }
  }
  elsif($interface eq 'set')
  {
    my $arg_check_code = 
      qq(Carp::croak ref(\$_[0]), ": Missing argument in call to $qname"  unless(\@_ > 1););

    my $code=<<"EOF";
sub
{
  $arg_check_code
  my \$self = shift;
  my \$value = shift;

  $check_in_code
  $min_max_code
  $set_code
  $return_code
};
EOF

    $Debug && warn "sub $name = ", $code;
    $methods{$name} = eval $code;

    if($@)
    {
      Carp::croak "Error in generated code for method $name - $@\n",
                  "Code was: $code";
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

1;

__END__

=head1 NAME

Rose::DB::Object::MakeMethods::Generic - Create generic object methods for Rose::DB::Object-derived objects.

=head1 SYNOPSIS

  package MyDBObject;

  our @ISA = qw(Rose::DB::Object);

  use Rose::DB::Object::MakeMethods::Generic
  (
    bigint => 
    [
      'count' => 
      {
        with_init => 1,
        min       => 0,
      },

      'tally' => { default => '9223372036854775800'},
    ],
  );

  sub init_type { 'C' }
  ...

  $o = MyDBObject->new(...);

  print $o->type; # C

  $o->name('Bob');   # set
  $o->set_type('C'); # set
  $o->type('AA');    # set

  $o->set_type; # Fatal error: no argument passed to "set" method

  $o->name('C' x 40); # truncate on set
  print $o->name;     # 'CCCCCCCCCC'

  $o->code('ABC'); # pad on set
  print $o->code;  # 'ABC   '

  eval { $o->type('foo') }; # fatal error: invalid value

  print $o->name, ' is ', $o->type; # get

  $obj->is_red;         # returns undef
  $obj->is_red('true'); # returns 1 (assuming "true" a
                        # valid boolean literal according to
                        # $obj->db->parse_boolean('true'))
  $obj->is_red('');     # returns 0
  $obj->is_red;         # returns 0

  $obj->is_happy;       # returns 1

  ...

  package Person;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    scalar => 'name',

    set => 
    [
      'nicknames',
      'parts' => { default => [ qw(arms legs) ] },
    ],

    # See the Rose::DB::Object::Metadata::Relationship::ManyToMany
    # documentation for a more complete example
    objects_by_map =>
    [
      friends =>
      {
        map_class    => 'FriendMap',
        manager_args => { sort_by => Friend->meta->table . '.name' },
      },
    ],
  );
  ...

  @parts = $person->parts; # ('arms', 'legs')
  $parts = $person->parts; # [ 'arms', 'legs' ]

  $person->nicknames('Jack', 'Gimpy');   # set with list
  $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

  print join(', ', map { $_->name } $person->friends);
  ...

  package Program;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    objects_by_key =>
    [
      bugs => 
      {
        class => 'Bug',
        key_columns =>
        {
          # Map Program column names to Bug column names
          id      => 'program_id',
          version => 'version',
        },
        manager_args => 
        {
          sort_by => Bug->meta->table . '.date_submitted DESC',
        },
        query_args   => [ state => { ne => 'closed' } ],
      },
    ]
  );
  ...

  $prog = Program->new(id => 5, version => '3.0', ...);

  $bugs = $prog->bugs;

  # Calls (essentially):
  #
  # Rose::DB::Object::Manager->get_objects(
  #   db           => $prog->db, # share_db defaults to true
  #   object_class => 'Bug',
  #   query =>
  #   {
  #     program_id => 5,     # value of $prog->id
  #     version    => '3.0', # value of $prog->version
  #     state      => { ne => 'closed' },
  #   },
  #   sort_by => 'date_submitted DESC');

  ...

  package Product;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    object_by_key =>
    [
      category => 
      {
        class => 'Category',
        key_columns =>
        {
          # Map Product column names to Category column names
          category_id => 'id',
        },
      },
    ]
  );
  ...

  $product = Product->new(id => 5, category_id => 99);

  $category = $product->category;

  # $product->category call is roughly equivalent to:
  #
  # $cat = Category->new(id => $product->category_id,
  #                      db => $prog->db);
  #
  # $ret = $cat->load;
  # return $ret  unless($ret);
  # return $cat;

=head1 DESCRIPTION

L<Rose::DB::Object::MakeMethods::Generic> is a method maker that inherits from L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation to learn about the interface.  The method types provided by this module are described below.

All method types defined by this module are designed to work with objects that are subclasses of (or otherwise conform to the interface of) L<Rose::DB::Object>.  In particular, the object is expected to have a L<db|Rose::DB::Object/db> method that returns a L<Rose::DB>-derived object.  See the L<Rose::DB::Object> documentation for more details.

=head1 METHODS TYPES

=over 4

=item B<array>

Create get/set methods for "array" attributes.   A "array" column in a database table contains an ordered list of values.  Not all databases support an "array" column type.  Check the L<Rose::DB|Rose::DB/"DATABASE SUPPORT"> documentation for your database type.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.  The value should be a reference to an array.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When setting the attribute, the value is passed through the L<parse_array|Rose::DB::Pg/parse_array> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

=item B<get>

Creates an accessor method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

=item B<set>

Creates a mutator method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When setting the attribute, the value is passed through the L<parse_array|Rose::DB::Pg/parse_array> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package Person;

    our @ISA = qw(Rose::DB::Object);
    ...
    use Rose::DB::Object::MakeMethods::Generic
    (
      array => 
      [
        'nicknames',
        set_nicks => { interface => 'set', hash_key => 'nicknames' },
        parts     => { default => [ qw(arms legs) ] },
      ],
    );
    ...

    @parts = $person->parts; # ('arms', 'legs')
    $parts = $person->parts; # [ 'arms', 'legs' ]

    $person->nicknames('Jack', 'Gimpy');   # set with list
    $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

    $person->set_nicks('Jack', 'Gimpy');   # set with list
    $person->set_nicks([ 'Slim', 'Gip' ]); # set with array ref

=item B<bitfield>

Create get/set methods for bitfield attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=item B<intersects NAME>

Set the name of the "intersects" method.  (See C<with_intersects> below.)  Defaults to the bitfield attribute method name with "_intersects" appended.

=item B<bits INT>

The number of bits in the bitfield.  Defaults to 32.

=item B<with_intersects BOOL>

This option is only applicable with the C<get_set> interface.

If true, create an "intersects" helper method in addition to the C<get_set> method.  The intersection method name will be the attribute method name with "_intersects" appended, or the value of the C<intersects> option, if it is passed.

The "intersects" method will return true if there is any intersection between its arguments and the value of the bitfield attribute (i.e., if L<Bit::Vector>'s L<Intersection|Bit::Vector/Intersection> method returns a value greater than zero), false (but defined) otherwise.  Its argument is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being tested for intersection.  Returns undef if the bitfield is not defined.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for a bitfield attribute.  When setting the attribute, the value is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being assigned.

When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item B<get>

Creates an accessor method for a bitfield attribute.  When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item B<set>

Creates a mutator method for a bitfield attribute.  When setting the attribute, the value is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being assigned.

When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      bitfield => 
      [
        'flags' => { size => 32, default => 2 },
        'bits'  => { size => 16, with_intersects => 1 },
      ],
    );

    ...

    print $o->flags->to_Bin; # 00000000000000000000000000000010

    $o->bits('101');

    $o->bits_intersects('100'); # true
    $o->bits_intersects('010'); # false

=item B<boolean>

Create get/set methods for boolean attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for a boolean attribute.  When setting the attribute, if the value is "true" according to Perl's rules, it is compared to a list of "common" true and false values: 1, 0, 1.0 (with any number of zeros), 0.0 (with any number of zeros), t, true, f, false, yes, no.  (All are case-insensitive.)  If the value matches, then it is set to true (1) or false (0) accordingly.

If the value does not match any of those, then it is passed through the L<parse_boolean|Rose::DB/parse_boolean> method of the object's L<db|Rose::DB::Object/db> attribute.  If L<parse_boolean|Rose::DB/parse_boolean> returns true (1) or false (0), then the attribute is set accordingly.  If L<parse_boolean|Rose::DB/parse_boolean> returns undef, a fatal error will occur.  If the value is "false" according to Perl's rules, the attribute is set to zero (0).

When saving to the database, the method will pass the attribute value through the L<format_boolean|Rose::DB/format_boolean> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item B<get>

Creates an accessor method for a boolean attribute.  When saving to the database, the method will pass the attribute value through the L<format_boolean|Rose::DB/format_boolean> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item B<set>

Creates a mutator method for a boolean attribute.  When setting the attribute, if the value is "true" according to Perl's rules, it is compared to a list of "common" true and false values: 1, 0, 1.0 (with any number of zeros), 0.0 (with any number of zeros), t, true, f, false, yes, no.  (All are case-insensitive.)  If the value matches, then it is set to true (1) or false (0) accordingly.

If the value does not match any of those, then it is passed through the L<parse_boolean|Rose::DB/parse_boolean> method of the object's L<db|Rose::DB::Object/db> attribute.  If L<parse_boolean|Rose::DB/parse_boolean> returns true (1) or false (0), then the attribute is set accordingly.  If L<parse_boolean|Rose::DB/parse_boolean> returns undef, a fatal error will occur.  If the value is "false" according to Perl's rules, the attribute is set to zero (0).

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      boolean => 
      [
        'is_red',
        'is_happy'  => { default => 1 },
        'set_happy' => { interface => 'set', hash_key => 'is_happy' },
      ],
    );

    $obj->is_red;         # returns undef
    $obj->is_red('true'); # returns 1 (assuming "true" a
                          # valid boolean literal according to
                          # $obj->db->parse_boolean('true'))
    $obj->is_red('');     # returns 0
    $obj->is_red;         # returns 0

    $obj->is_happy;       # returns 1
    $obj->set_happy(0);   # returns 0
    $obj->is_happy;       # returns 0

=item B<character>

Create get/set methods for fixed-length character string attributes.

=over 4

=item Options

=over 4

=item B<check_in ARRAYREF>

A reference to an array of valid values.  When setting the attribute, if the new value is not equal (string comparison) to one of the valid values, a fatal error will occur.

=item B<default VALUE>

Determines the default value of the attribute.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this attribute.  Defaults to the name of the method.

=item B<init_method NAME>

The name of the method to call when initializing the value of an undefined attribute.  Defaults to the method name with the prefix C<init_> added.  This option implies C<with_init>.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=item B<length INT>

The number of characters in the string.  Any strings shorter than this will be padded with spaces to meet the length requirement.  If length is omitted, the string will be left unmodified.

=item B<overflow BEHAVIOR>

Determines the behavior when the value is greater than the number of characters specified by the C<length> option.  Valid values for BEHAVIOR are:

=over 4

=item B<fatal>

Throw an exception.

=item B<truncate>

Truncate the value to the correct length.

=item B<warn>

Print a warning message.

=back

=item B<with_init BOOL>

Modifies the behavior of the C<get_set> and C<get> interfaces.  If the attribute is undefined, the method specified by the C<init_method> option is called and the attribute is set to the return value of that
method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for a fixed-length character string attribute.  When setting, any strings longer than C<length> will be truncated, and any strings shorter will be padded with spaces to meet the length requirement.  If C<length> is omitted, the string will be left unmodified.

=item B<get>

Creates an accessor method for a fixed-length character string attribute.

=item B<set>

Creates a mutator method for a fixed-length character string attribute.  Any strings longer than C<length> will be truncated, and any strings shorter will be padded with spaces to meet the length requirement.  If C<length> is omitted, the string will be left unmodified.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      character => 
      [
        'name' => { length => 3 },
      ],
    );

    ...

    $o->name('John'); # truncates on set
    print $o->name;   # 'Joh'

    $o->name('A'); # pads on set
    print $o->name;   # 'A  '

=item B<enum>

Create get/set methods for enum attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<values ARRAYREF>

A reference to an array of the enum values.  This attribute is required.  When setting the attribute, if the new value is not equal (string comparison) to one of the enum values, a fatal error will occur.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this attribute.  Defaults to the name of the method.

=item B<init_method NAME>

The name of the method to call when initializing the value of an undefined attribute.  Defaults to the method name with the prefix C<init_> added.  This option implies C<with_init>.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<with_init BOOL>

Modifies the behavior of the C<get_set> and C<get> interfaces.  If the attribute is undefined, the method specified by the C<init_method> option is called and the attribute is set to the return value of that
method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for an enum attribute.  When called with an argument, the value of the attribute is set.  If the value is invalid, a fatal error will occur.  The current value of the attribute is returned.

=item B<get>

Creates an accessor method for an object attribute that returns the current value of the attribute.

=item B<set>

Creates a mutator method for an object attribute.  When called with an argument, the value of the attribute is set.  If the value is invalid, a fatal error will occur.  If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      enum => 
      [
        type  => { values => [ qw(main aux extra) ], default => 'aux' },
        stage => { values => [ qw(new std old) ], with_init => 1 },
      ],
    );

    sub init_stage { 'new' }
    ...

    $o = MyDBObject->new(...);

    print $o->type;   # aux
    print $o->stage;  # new

    $o->type('aux');  # set
    $o->stage('old'); # set

    eval { $o->type('foo') }; # fatal error: invalid value

    print $o->type, ' is at stage ', $o->stage; # get

=item B<integer>

Create get/set methods for integer attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this attribute.  Defaults to the name of the method.

=item B<init_method NAME>

The name of the method to call when initializing the value of an undefined attribute.  Defaults to the method name with the prefix C<init_> added.  This option implies C<with_init>.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<with_init BOOL>

Modifies the behavior of the C<get_set> and C<get> interfaces.  If the attribute is undefined, the method specified by the C<init_method> option is called and the attribute is set to the return value of that method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for an integer object attribute.  When called with an argument, the value of the attribute is set.  The current value of the attribute is returned.

=item B<get>

Creates an accessor method for an integer object attribute that returns the current value of the attribute.

=item B<set>

Creates a mutator method for an integer object attribute.  When called with an argument, the value of the attribute is set.  If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      integer => 
      [
        code => { default => 99  },
        type => { with_init => 1 }
      ],
    );

    sub init_type { 123 }
    ...

    $o = MyDBObject->new(...);

    print $o->code; # 99
    print $o->type; # 123

    $o->code(8675309); # set
    $o->type(42);      # set


=item B<objects_by_key>

Create get/set methods for an array of L<Rose::DB::Object>-derived objects fetched based on a key formed from attributes of the current object.

=over 4

=item Options

=over 4

=item B<class CLASS>

The name of the L<Rose::DB::Object>-derived class of the objects to be fetched.  This option is required.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of the fetched objects.  Defaults to the name of the method.

=item B<key_columns HASHREF>

A reference to a hash that maps column names in the current object to those in the objects to be fetched.  This option is required.

=item B<manager_args HASHREF>

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.  If C<manager_class> defaults to L<Rose::DB::Object::Manager>, the following argument is added to the C<manager_args> hash: C<object_class =E<gt> CLASS>, where CLASS is the value of the C<class> option (see above).  If C<manager_args> includes a "sort_by" argument, be sure to prefix each column name with the appropriate table name.  (See the L<synopsis|/SYNOPSIS> for examples.)

=item B<manager_class CLASS>

The name of the L<Rose::DB::Object::Manager>-derived class used to fetch the objects.  The C<manager_method> class method is called on this class.  Defaults to L<Rose::DB::Object::Manager>.

=item B<manager_method NAME>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<relationship OBJECT>

The L<Rose::DB::Object::Metadata::Relationship> object that describes the "key" through which the "objects_by_key" are fetched.  This is required when using the "add_now", "add_on_save", and "get_set_on_save" interfaces.

=item B<share_db BOOL>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item B<query_args ARRAYREF>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object.

If passed a single argument of undef, the C<hash_key> used to store the objects is set to undef.  Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>.  Note that these objects are B<not> added to the database.  Use the C<get_set_now> or C<get_set_on_save> interface to do that.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<get_set_now>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object, and will also save the objects to the database when called with arguments.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>, the old objects are deleted from the database, and the new ones are added to the database.  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

When adding each object, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d, a fatal error will occur.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<get_set_on_save>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object, and will also save the objects to the database when the "parent" object is L<save|Rose::DB::Object/save>d.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be deleted from the database when the parent is L<save|Rose::DB::Object/save>d.)

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>.  The old objects are scheduled to be deleted from the database and the new ones are scheduled to be added to the database when the parent is L<save|Rose::DB::Object/save>d.  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

When adding each object when the parent is L<save|Rose::DB::Object/save>d, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<add_now>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object by a key formed from attributes of the current object.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

If passed any arguments, the parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d prior to adding to the list of objects.  If this method is called with a non-empty list as an argument before the parent object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d, a fatal error will occur.

The argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

These objects are linked to the parent object (by setting the appropriate key attributes) and then added to the database.

When adding each object, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

The parent object's list of related objects is then set to undef, causing the related objects to be reloaded from the database the next time they're needed.

=item B<add_on_save>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object by a key formed from attributes of the current object.  The objects will be added to the database when the parent object is L<save|Rose::DB::Object/save>d.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

These objects are linked to the parent object (by setting the appropriate key attributes, whether or not they're defined in the parent object) and are scheduled to be added to the database when the parent object is L<save|Rose::DB::Object/save>d.  They are also added to the parent object's current list of related objects, if the list is defined at the time of the call.

When adding each object when the parent is L<save|Rose::DB::Object/save>d, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

=back

=back

Example setup:

    # CLASS     DB TABLE
    # -------   --------
    # Program   programs
    # Bug       bugs

    package Program;

    our @ISA = qw(Rose::DB::Object);
    ...
    # You will almost never call the method-maker directly
    # like this.  See the Rose::DB::Object::Metadata docs
    # for examples of more common usage.
    use Rose::DB::Object::MakeMethods::Generic
    (
      objects_by_key =>
      [
        bugs => 
        {
          interface => '...', # get_set, get_set_now, get_set_on_save
          class     => 'Bug',
          key_columns =>
          {
            # Map Program column names to Bug column names
            id      => 'program_id',
            version => 'version',
          },
          manager_args => { sort_by => 'date_submitted DESC' },
          query_args   => { state => { ne => 'closed' } },
        },

        add_bugs => 
        {
          interface => '...', # add_now or add_on_save
          class     => 'Bug',
          key_columns =>
          {
            # Map Program column names to Bug column names
            id      => 'program_id',
            version => 'version',
          },
          manager_args => { sort_by => 'date_submitted DESC' },
          query_args   => { state => { ne => 'closed' } },
        },
      ]
    );
    ...

Example - get_set interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    # Calls (essentially):
    #
    # Rose::DB::Object::Manager->get_objects(
    #   db           => $prog->db, # share_db defaults to true
    #   object_class => 'Bug',
    #   query =>
    #   {
    #     program_id => 5,     # value of $prog->id
    #     version    => '3.0', # value of $prog->version
    #     state      => { ne => 'closed' },
    #   },
    #   sort_by => 'date_submitted DESC');
    ...
    $prog->version($new_version); # Does not hit the db
    $prog->bugs(@new_bugs);       # Does not hit the db

    # @new_bugs can contain any mix of these types:
    #
    # @new_bugs =
    # (
    #   123,                 # primary key value
    #   { id => 456 },       # method name/value pairs
    #   Bug->new(id => 789), # object
    # );

    # Write to the programs table only.  The bugs table is not
    # updated. See the get_set_now and get_set_on_save method
    # types for ways to write to the bugs table.
    $prog->save;

Example - get_set_now interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db

    # Writes to the bugs table, deleting existing bugs and
    # replacing them with @new_bugs (which must be an array
    # of Bug objects, either existing or new)
    $prog->bugs(@new_bugs); 

    # @new_bugs can contain any mix of these types:
    #
    # @new_bugs =
    # (
    #   123,                 # primary key value
    #   { id => 456 },       # method name/value pairs
    #   Bug->new(id => 789), # object
    # );

    # Write to the programs table
    $prog->save;

Example - get_set_on_save interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db
    $prog->bugs(@new_bugs); # Does not hit the db

    # @new_bugs can contain any mix of these types:
    #
    # @new_bugs =
    # (
    #   123,                 # primary key value
    #   { id => 456 },       # method name/value pairs
    #   Bug->new(id => 789), # object
    # );

    # Write to the programs table and the bugs table, deleting any
    # existing bugs and replacing them with @new_bugs (which must be
    # an array of Bug objects, either existing or new)
    $prog->save;

Example - add_now interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db

    # Writes to the bugs table, adding @new_bugs to the current
    # list of bugs for this program
    $prog->add_bugs(@new_bugs);

    # @new_bugs can contain any mix of these types:
    #
    # @new_bugs =
    # (
    #   123,                 # primary key value
    #   { id => 456 },       # method name/value pairs
    #   Bug->new(id => 789), # object
    # );

    # Read from the bugs table, getting the full list of bugs, 
    # including the ones that were added above.
    $bugs = $prog->bugs;

    # Write to the programs table only
    $prog->save;

Example - add_on_save interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name);     # Does not hit the db
    $prog->add_bugs(@new_bugs); # Does not hit the db

    # @new_bugs can contain any mix of these types:
    #
    # @new_bugs =
    # (
    #   123,                 # primary key value
    #   { id => 456 },       # method name/value pairs
    #   Bug->new(id => 789), # object
    # );

    # Write to the programs table and the bugs table, adding
    # @new_bugs to the current list of bugs for this program
    $prog->save;

=item B<objects_by_map>

Create methods that fetch L<Rose::DB::Object>-derived objects via an intermediate L<Rose::DB::Object>-derived class that maps between two other L<Rose::DB::Object>-derived classes.  See the L<Rose::DB::Object::Metadata::Relationship::ManyToMany> documentation for a more complete example of this type of method in action.

=over 4

=item Options

=over 4

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of the fetched objects.  Defaults to the name of the method.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<manager_args HASHREF>

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.  If C<manager_args> includes a "sort_by" argument, be sure to prefix each column name with the appropriate table name.  (See the L<synopsis|/SYNOPSIS> for examples.)

=item B<manager_class CLASS>

The name of the L<Rose::DB::Object::Manager>-derived class that the C<map_class> will use to fetch records.  Defaults to L<Rose::DB::Object::Manager>.

=item B<manager_method NAME>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item B<map_class CLASS>

The name of the L<Rose::DB::Object>-derived class that maps between the other two L<Rose::DB::Object>-derived classes.  This class must have a foreign key and/or "many to one" relationship for each of the two tables that it maps between.

=item B<map_from NAME>

The name of the "many to one" relationship or foreign key in C<map_class> that points to the object of the class that this relationship exists in.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

=item B<map_to NAME>

The name of the "many to one" relationship or foreign key in C<map_class> that points to the "foreign" object to be fetched.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

=item B<relationship OBJECT>

The L<Rose::DB::Object::Metadata::Relationship> object that describes the "key" through which the "objects_by_key" are fetched.  This option is required.

=item B<share_db BOOL>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item B<query_args ARRAYREF>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>.

If passed a single argument of undef, the C<hash_key> used to store the objects is set to undef.  Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>.  Note that these objects are B<not> added to the database.  Use the C<get_set_now> or C<get_set_on_save> interface to do that.

When fetching objects from the database, if the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<get_set_now>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when called with arguments.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be "unmapped"--that is, to have their entries in the mapping table deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>, the old entries are deleted from the mapping table in the database, and the new objects are added to the database, along with their corresponding mapping entries.  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

When adding each object, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d, a fatal error will occur.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

When fetching, if the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<get_set_on_save>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when the "parent" object is L<save|Rose::DB::Object/save>d.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be "unmapped"--that is, to have their entries in the mapping table deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The list of object is assigned to C<hash_key>. The mapping table records that mapped the old objects to the parent object are scheduled to be deleted from the database and new ones are scheduled to be added to the database when the parent is L<save|Rose::DB::Object/save>d.  Any previously pending C<set_on_save> or C<add_on_save> actions are discarded.

When adding each object when the parent is L<save|Rose::DB::Object/save>d, if the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or  L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

When fetching, if the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item B<add_now>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

If passed any arguments, the parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d prior to adding to the list of objects.  If this method is called with a non-empty list as an argument before the parent object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d, a fatal error will occur.

The argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The parent object's list of related objects is then set to undef, causing the related objects to be reloaded from the database the next time they're needed.

=item B<add_on_save>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when the "parent" object is L<save|Rose::DB::Object/save>d.  The objects and map records will be added to the database when the parent object is L<save|Rose::DB::Object/save>d.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

Otherwise, the argument(s) must be a list or reference to an array containing items in one or more of the following formats:

=over 4

=item * An object of type C<class>

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter two formats will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

These objects are scheduled to be added to the database and mapped to the parent object when the parent object is L<save|Rose::DB::Object/save>d.  They are also added to the parent object's current list of related objects, if the list is defined at the time of the call.

=back

=back

For a complete example of this method type in action, see the L<Rose::DB::Object::Metadata::Relationship::ManyToMany> documentation.

=item B<object_by_key>

Create a get/set methods for a single L<Rose::DB::Object>-derived object loaded based on a primary key formed from attributes of the current object.

=over 4

=item Options

=over 4

=item B<class CLASS>

The name of the L<Rose::DB::Object>-derived class of the object to be loaded.  This option is required.

=item B<foreign_key OBJECT>

The L<Rose::DB::Object::Metadata::ForeignKey> object that describes the "key" through which the "object_by_key" is fetched.  This is required when using the "delete_now", "delete_on_save", and "get_set_on_save" interfaces.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of the object.  Defaults to the name of the method.

=item B<if_not_found CONSEQUENCE>

This setting determines what happens when the key_columns have defined values, but the foreign object they point to is not found.  Valid values for CONSEQUENCE are C<fatal>, which will throw an exception if the foreign object is not found, and C<ok> which will merely cause the relevant method(s) to return undef.  The default is C<fatal>. 

=item B<key_columns HASHREF>

A reference to a hash that maps column names in the current object to those of the primary key in the object to be loaded.  This option is required.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=item B<share_db BOOL>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with the object loaded.  Defaults to true.

=back

=item Interfaces

=over 4

=item B<delete_now>

Deletes a L<Rose::DB::Object>-derived object from the database based on a primary key formed from attributes of the current object.  First, the "parent" object will have all of its attributes that refer to the "foreign" set to null, and it will be saved into the database.  This needs to be done first because a database that enforces referential integrity will not allow a row to be deleted if it is still referenced by a foreign key in another table.

Any previously pending C<get_set_on_save> action is discarded.

The entire process takes place within a transaction if the database supports it.  If not currently in a transaction, a new one is started and then committed on success and rolled back on failure.

Returns true if the foreign object was deleted successfully or did not exist in the database, false if any of the keys that refer to the foreign object were undef, and triggers the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> in the case of any other kind of failure.

=item B<delete_on_save>

Deletes a L<Rose::DB::Object>-derived object from the database when the "parent" object is L<save|Rose::DB::Object/save>d, based on a primary key formed from attributes of the current object.  The "parent" object will have all of its attributes that refer to the "foreign" set to null immediately, but the actual delete will not be done until the parent is saved.

Any previously pending C<get_set_on_save> action is discarded.

The entire process takes place within a transaction if the database supports it.  If not currently in a transaction, a new one is started and then committed on success and rolled back on failure.

Returns true if the foreign object was deleted successfully or did not exist in the database, false if any of the keys that refer to the foreign object were undef, and triggers the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> in the case of any other kind of failure.

=item B<get_set>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument must be one of the following:

=over 4

=item * An object of type C<class>

=item * A list of method name/value pairs.

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter three argument types will be used to construct an object of type C<class>.  A single primary key value is only valid if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The object is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=item B<get_set_now>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object, and will also save the object to the database when called with an appropriate object as an argument.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument must be one of the following:

=over 4

=item * An object of type C<class>

=item * A list of method name/value pairs.

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter three argument types will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The object is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.  The object is then immediately L<save|Rose::DB::Object/save>d to the database.

If the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>d, a fatal error will occur.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=item B<get_set_on_save>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object, and save the object when the "parent" object is L<save|Rose::DB::Object/save>d.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument must be one of the following:

=over 4

=item * An object of type C<class>

=item * A list of method name/value pairs.

=item * A reference to a hash containing method name/value pairs.

=item * A single scalar primary key value

=back

The latter three argument types will be used to construct an object of type C<class>.  A single primary key value is only a valid argument format if the C<class> in question has a single-column primary key.  A hash reference argument must contain sufficient information for the object to be uniquely identified.

The object is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.  The object will be saved into the database when the "parent" object is L<save|Rose::DB::Object/save>d.  Any previously pending C<get_set_on_save> action is discarded.

If the object does not already exists in the database, it will be inserted.  If the object was previously L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d to the database, it will be updated.  Otherwise, it will be L<load|Rose::DB::Object/load>ed.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded from the database.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=back

=back

Example setup:

    # CLASS     DB TABLE
    # -------   --------
    # Product   products
    # Category  categories

    package Product;

    our @ISA = qw(Rose::DB::Object);
    ...

    # You will almost never call the method-maker directly
    # like this.  See the Rose::DB::Object::Metadata docs
    # for examples of more common usage.
    use Rose::DB::Object::MakeMethods::Generic
    (
      object_by_key =>
      [
        category => 
        {
          interface   => 'get_set',
          class       => 'Category',
          key_columns =>
          {
            # Map Product column names to Category column names
            category_id => 'id',
          },
        },
      ]
    );
    ...

Example - get_set interface:

    $product = Product->new(id => 5, category_id => 99);

    # Read from the categories table
    $category = $product->category; 

    # $product->category call is roughly equivalent to:
    #
    # $cat = Category->new(id => $product->category_id
    #                      db => $prog->db);
    #
    # $ret = $cat->load;
    # return $ret  unless($ret);
    # return $cat;

    # Does not write to the db
    $product->category(Category->new(...));

    $product->save; # writes to products table only

Example - get_set_now interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Read from the categories table
    $category = $product->category;

    # Write to the categories table:
    # (all possible argument formats show)

    # Object argument
    $product->category(Category->new(...));

    # Primary key value
    $product->category(123); 

    # Method name/value pairs in a hashref
    $product->category(id => 123); 

    # Method name/value pairs in a hashref
    $product->category({ id => 123 }); 

    # Write to the products table
    $product->save; 

Example - get_set_on_save interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Read from the categories table
    $category = $product->category;

    # These do not write to the db:

    # Object argument
    $product->category(Category->new(...));

    # Primary key value
    $product->category(123); 

    # Method name/value pairs in a hashref
    $product->category(id => 123); 

    # Method name/value pairs in a hashref
    $product->category({ id => 123 });

    # Write to both the products and categories tables
    $product->save; 

Example - delete_now interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Write to both the categories and products tables
    $product->delete_category();

Example - delete_on_save interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Does not write to the db
    $product->delete_category(); 

    # Write to both the products and categories tables
    $product->save;

=item B<scalar>

Create get/set methods for scalar attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<check_in ARRAYREF>

A reference to an array of valid values.  When setting the attribute, if the new value is not equal (string comparison) to one of the valid values, a fatal error will occur.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item B<init_method NAME>

The name of the method to call when initializing the value of an undefined attribute.  Defaults to the method name with the prefix C<init_> added.  This option implies C<with_init>.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<length INT>

The maximum number of characters in the string.

=item B<overflow BEHAVIOR>

Determines the behavior when the value is greater than the number of characters specified by the C<length> option.  Valid values for BEHAVIOR are:

=over 4

=item B<fatal>

Throw an exception.

=item B<truncate>

Truncate the value to the correct length.

=item B<warn>

Print a warning message.

=back

=item B<with_init BOOL>

Modifies the behavior of the C<get_set> and C<get> interfaces.  If the attribute is undefined, the method specified by the C<init_method> option is called and the attribute is set to the return value of that
method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for an object attribute.  When called with an argument, the value of the attribute is set.  The current value of the attribute is returned.

=item B<get>

Creates an accessor method for an object attribute that returns the current value of the attribute.

=item B<set>

Creates a mutator method for an object attribute.  When called with an argument, the value of the attribute is set.  If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      scalar => 
      [
        name => { default => 'Joe' },
        type => 
        {
          with_init => 1,
          check_in  => [ qw(AA AAA C D) ],
        }
        set_type =>
        {
          check_in  => [ qw(AA AAA C D) ],        
        }
      ],
    );

    sub init_type { 'C' }
    ...

    $o = MyDBObject->new(...);

    print $o->name; # Joe
    print $o->type; # C

    $o->name('Bob'); # set
    $o->type('AA');  # set

    eval { $o->type('foo') }; # fatal error: invalid value

    print $o->name, ' is ', $o->type; # get

=item B<set>

Create get/set methods for "set" attributes.   A "set" column in a database table contains an unordered group of values.  Not all databases support a "set" column type.  Check the L<Rose::DB|Rose::DB/"DATABASE SUPPORT"> documentation for your database type.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.  The value should be a reference to an array.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item B<interface NAME>

Choose the interface.  The default is C<get_set>.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When setting the attribute, the value is passed through the L<parse_set|Rose::DB::Informix/parse_set> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=item B<get>

Creates an accessor method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=item B<set>

Creates a mutator method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When setting the attribute, the value is passed through the L<parse_set|Rose::DB::Informix/parse_set> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=back

=back

Example:

    package Person;

    our @ISA = qw(Rose::DB::Object);
    ...
    use Rose::DB::Object::MakeMethods::Generic
    (
      set => 
      [
        'nicknames',
        'set_nicks' => { interface => 'set', hash_key => 'nicknames' },

        'parts' => { default => [ qw(arms legs) ] },
      ],
    );
    ...

    @parts = $person->parts; # ('arms', 'legs')
    $parts = $person->parts; # [ 'arms', 'legs' ]

    $person->nicknames('Jack', 'Gimpy');   # set with list
    $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

    $person->set_nicks('Jack', 'Gimpy');   # set with list
    $person->set_nicks([ 'Slim', 'Gip' ]); # set with array ref

=item B<varchar>

Create get/set methods for variable-length character string attributes.

=over 4

=item Options

=over 4

=item B<default VALUE>

Determines the default value of the attribute.

=item B<hash_key NAME>

The key inside the hash-based object to use for the storage of this attribute.  Defaults to the name of the method.

=item B<init_method NAME>

The name of the method to call when initializing the value of an undefined attribute.  Defaults to the method name with the prefix C<init_> added.  This option implies C<with_init>.

=item B<interface NAME>

Choose the interface.  The C<get_set> interface is the default.

=item B<length INT>

The maximum number of characters in the string.

=item B<overflow BEHAVIOR>

Determines the behavior when the value is greater than the number of characters specified by the C<length> option.  Valid values for BEHAVIOR are:

=over 4

=item B<fatal>

Throw an exception.

=item B<truncate>

Truncate the value to the correct length.

=item B<warn>

Print a warning message.

=back

=item B<with_init BOOL>

Modifies the behavior of the C<get_set> and C<get> interfaces.  If the attribute is undefined, the method specified by the C<init_method> option is called and the attribute is set to the return value of that
method.

=back

=item Interfaces

=over 4

=item B<get_set>

Creates a get/set accessor method for a fixed-length character string attribute.  When setting, any strings longer than C<length> will be truncated.  If C<length> is omitted, the string will be left unmodified.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      varchar => 
      [
        'name' => { length => 3 },
      ],
    );

    ...

    $o->name('John'); # truncates on set
    print $o->name;   # 'Joh'

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
