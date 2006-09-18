package Rose::DB::Informix;

use strict;

use Rose::DateTime::Util();

our $VERSION = '0.742';

our $Debug = 0;

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 'max_array_characters',
);

__PACKAGE__->max_array_characters(255);

#
# Object methods
#

sub build_dsn
{
  my($self_or_class, %args) = @_;
  return "dbi:$args{'driver'}:" . ($args{'db'} || $args{'database'});
}

sub last_insertid_from_sth { $_[1]->{'ix_sqlerrd'}[1] }

sub likes_lowercase_table_names { 1 }
sub generate_primary_key_values { return; } # old perls seem to like this...

sub generate_primary_key_placeholders
{
  (@_ == 1 || (@_ > 1 && $_[1] == 1)) ? 0 : ((undef) x $_[1]) 
}

# Informix doesn't like anything to be quoted and appears to
# accept everything without quotes.
sub is_reserved_word { 0 }

# Boolean formatting and parsing

sub format_boolean { $_[1] ? 't' : 'f' }

sub parse_boolean
{
  my($self, $value) = @_;
  return $value  if($self->validate_boolean_keyword($_[1]) || $_[1] =~ /^\w+\(.*\)$/);
  return 1  if($value =~ /^[t1]$/i);
  return 0  if($value =~ /^[f0]$/i);

  $self->error("Invalid boolean value: '$value'");
  return undef;
}

# Date formatting

sub format_date
{  
  return $_[1]  if($_[0]->validate_date_keyword($_[1]));
  return Rose::DateTime::Util::format_date($_[1], '%m/%d/%Y');
}

sub format_datetime
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));
  return Rose::DateTime::Util::format_date($_[1], '%Y-%m-%d %H:%M:%S');
}

sub format_datetime_year_to_second
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));
  return Rose::DateTime::Util::format_date($_[1], '%Y-%m-%d %H:%M:%S');
}

sub format_datetime_year_to_minute
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));
  return Rose::DateTime::Util::format_date($_[1], '%Y-%m-%d %H:%M');
}

# sub format_time
# {
#   return $_[1]  if($_[0]->validate_time_keyword($_[1]));
#   return Rose::DateTime::Util::format_date($_[1], '%H:%M:%S');
# }

sub format_timestamp
{  
  return $_[1]  if($_[0]->validate_timestamp_keyword($_[1]));
  return Rose::DateTime::Util::format_date($_[1], '%Y-%m-%d %H:%M:%S.%5N');
}

sub format_datetime_year_to_fraction
{
  my($self, $dt, $fraction) = @_;

  $fraction ||= 3;

  return $dt  if($self->validate_datetime_year_to_fraction_keyword($dt));
  return Rose::DateTime::Util::format_date($dt, "%Y-%m-%d %H:%M:%S.%${fraction}N");
}

sub format_datetime_year_to_fraction_1 { format_datetime_year_to_fraction(@_, 1) }
sub format_datetime_year_to_fraction_2 { format_datetime_year_to_fraction(@_, 2) }
sub format_datetime_year_to_fraction_3 { format_datetime_year_to_fraction(@_, 3) }
sub format_datetime_year_to_fraction_4 { format_datetime_year_to_fraction(@_, 4) }
sub format_datetime_year_to_fraction_5 { format_datetime_year_to_fraction(@_, 5) }

# Date parsing

sub parse_date
{
  return $_[1]  if($_[0]->validate_date_keyword($_[1]));

  my $dt = Rose::DateTime::Util::parse_date($_[1]);

  if($@)
  {
    $_[0]->error("Could not parse date '$_[1]' - $@");
    return undef;
  }

  return $dt;
}

sub parse_datetime
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));

  my $dt = Rose::DateTime::Util::parse_date($_[1]);

  if($@)
  {
    $_[0]->error("Could not parse datetime '$_[1]' - $@");
    return undef;
  }

  return $dt;
}

sub parse_datetime_year_to_second
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));

  my $dt = Rose::DateTime::Util::parse_date($_[1]);

  if($@)
  {
    $_[0]->error("Could not parse datetime year to second '$_[1]' - $@");
    return undef;
  }

  $dt->truncate(to => 'second')  if(ref $dt);
  return $dt;
}

sub parse_datetime_year_to_fraction
{
  my($self, $arg, $fraction) = @_;

  return $arg  if($self->validate_datetime_year_to_fraction_keyword($arg));

  $fraction ||= 3;

  my $dt = Rose::DateTime::Util::parse_date($arg);

  if($@)
  {
    $self->error("Could not parse datetime year to second '$arg' - $@");
    return undef;
  }

  if(ref $dt)
  {
    # Truncate nanosecs to correct fraction. (Yes, using strings. I am lame.)
    my $n = sprintf('%09d', $dt->nanosecond);
    $n = substr($n, 0, $fraction);

    if(length $n < 9)
    {
      $n .= ('0' x (9 - length $n));
    }

    $dt->set_nanosecond($n);
  }

  return $dt;
}

*parse_datetime_year_to_fraction_1 = sub { parse_datetime_year_to_fraction(@_, 1) };
*parse_datetime_year_to_fraction_2 = sub { parse_datetime_year_to_fraction(@_, 2) };
*parse_datetime_year_to_fraction_3 = sub { parse_datetime_year_to_fraction(@_, 3) };
*parse_datetime_year_to_fraction_4 = sub { parse_datetime_year_to_fraction(@_, 4) };
*parse_datetime_year_to_fraction_5 = sub { parse_datetime_year_to_fraction(@_, 5) };

sub parse_datetime_year_to_minute
{
  return $_[1]  if($_[0]->validate_datetime_keyword($_[1]));

  my $dt = Rose::DateTime::Util::parse_date($_[1]);


  if($@)
  {
    $_[0]->error("Could not parse datetime year to minute '$_[1]' - $@");
    return undef;
  }

  $dt->truncate(to => 'minute')  if(ref $dt);
  return $dt;
}

sub parse_timestamp
{
  return $_[1]  if($_[0]->validate_timestamp_keyword($_[1]));

  my $dt = Rose::DateTime::Util::parse_date($_[1]);

  if($@)
  {
    $_[0]->error("Could not parse timestamp '$_[1]' - $@");
    return undef;
  }

  return $dt;
}

sub validate_date_keyword
{
  no warnings;
  $_[1] =~ /^(?:current|today|\w+\(.*\))$/i;
}

sub validate_time_keyword
{
  no warnings;
  $_[1] =~ /^(?:current|\w+\(.*\))$/i;
}

sub validate_timestamp_keyword
{
  no warnings;
  $_[1] =~ /^(?:current(?: +year +to +(?:fraction(?:\([1-5]\))?|second|minute|hour|day|month))?|today|\w+\(.*\))$/i;
}

sub validate_datetime_year_to_fraction_keyword
{
  no warnings;
  $_[1] =~ /^(?:current(?: +year +to +(?:fraction(?:\([1-5]\))?|second|minute|hour|day|month))?|today|\w+\(.*\))$/i;
}

sub validate_datetime_keyword
{
  no warnings;
  $_[1] =~ /^(?:current(?: +year +to +(?:second|minute|hour|day|month))?|today|\w+\(.*\))$/i;
}

sub validate_datetime_year_to_second_keyword
{
  no warnings;
  $_[1] =~ /^(?:current(?: +year +to +(?:second|minute|hour|day|month))?|today|\w+\(.*\))$/i;
}

sub validate_datetime_year_to_minute_keyword
{
  no warnings;
  $_[1] =~ /^(?:current(?: +year +to +(?:minute|hour|day|month))?|today|\w+\(.*\))$/i;
}

sub parse_set
{
  my($self) = shift;

  return $_[0]  if(ref $_[0]);
  return [ @_ ] if(@_ > 1);

  my $val = $_[0];

  return undef  unless(defined $val);

  $val =~ s/^SET\{(.*)\}$/$1/;

  my @set;

  while($val =~ s/(?:'((?:[^'\\]+|\\.)*)'|([^',]+))(?:,|$)//)
  {
    push(@set, (defined $1) ? $1 : $2);
  }

  return \@set;
}

sub format_set
{
  my($self) = shift;

  my @set = (ref $_[0]) ? @{$_[0]} : @_;

  return undef  unless(@set && defined $set[0]);

  return 'SET{' . join(',', map 
  {
    if(!defined $_)
    {
      Carp::croak 'Undefined value found in array or list passed to ',
                  __PACKAGE__, '::format_set()';
    }
    elsif(/^[-+]?\d+(?:\.\d*)?$/)
    {
      $_
    }
    else
    {
      s/\\/\\\\/g; 
      s/'/\\'/g;
      qq('$_') 
    }
  } @set) . '}';
}

sub parse_array
{
  my($self) = shift;

  return $_[0]  if(ref $_[0]);
  return [ @_ ] if(@_ > 1);

  my $val = $_[0];

  return undef  unless(defined $val);

  $val =~ s/^\{(.*)\}$/$1/;

  my @array;

  while($val =~ s/(?:"((?:[^"\\]+|\\.)*)"|([^",]+))(?:,|$)//)
  {
    push(@array, (defined $1) ? $1 : $2);
  }

  return \@array;
}

sub format_array
{
  my($self) = shift;

  my @array = (ref $_[0]) ? @{$_[0]} : @_;

  return undef  unless(@array && defined $array[0]);

  my $str = '{' . join(',', map 
  {
    if(!defined $_)
    {
      Carp::croak 'Undefined value found in array or list passed to ',
                  __PACKAGE__, '::format_array()';
    }
    elsif(/^[-+]?\d+(?:\.\d*)?$/)
    {
      $_
    }
    else
    {
      s/\\/\\\\/g; 
      s/"/\\"/g;
      qq("$_") 
    }
  } @array) . '}';

  if(length($str) > $self->max_array_characters)
  {
    Carp::croak "Array string is longer than ", ref($self), 
                "->max_array_characters (", $self->max_array_characters,
                ") characters long: $str";
  }

  return $str;
}

sub next_value_in_sequence
{
  my($self, $seq) = @_;

  my $dbh = $self->dbh or return undef;

  my $id;

  eval
  {
    my $sth = $dbh->prepare(qq(SELECT nextval('$seq')));
    $sth->execute;
    $id = ${$sth->fetchrow_arrayref}[0];
  };

  if($@)
  {
    $self->error("Could not get the next value in the sequence '$seq' - $@");
    return undef;
  }

  return $id;
}

sub supports_limit_with_offset
{
  my($self) = shift;

  my $dbh = $self->dbh or return 0;

  # "1000" is what Informix version 10 seems to return
  return $dbh->{'ix_ProductVersion'} >= 1000 ? 1 : 0;
  return 0;
}

sub format_limit_with_offset
{
  #my($self, $limit, $offset) = @_;
  return @_ > 2 ? "SKIP $_[2] FIRST $_[1]" : "FIRST $_[1]";
}

sub supports_select_from_subselect { 0 } # can't handle serial columns in multiset
sub format_select_from_subselect { "\nTABLE(MULTISET(($_[1])))\n  " }

#
# Introspection
#

sub list_tables
{
  my($self, %args) = @_;

  my @tables;

  eval
  {
    my $dbh = $self->dbh or die $self->error;

    local $dbh->{'RaiseError'} = 1;

    my @table_info = $dbh->func('user', '_tables');

    my $schema = $self->schema;

    #if($args{'include_views'})
    #{
    #  my @view_info = $dbh->func('view', '_tables');
    #  push(@table_info, @view_info);
    #}

    my %seen;

    foreach my $item (@table_info)
    {
      # From DBD::Informix::Metadata:
      #
      # The owner name will be enclosed in double quotes; if it contains
      # double quotes, those will be doubled up as required by SQL.  The
      # table name will only be enclosed in double quotes if it is not a
      # valid C identifier (meaning, it starts with an alphabetic
      # character or underscore, and continues with alphanumeric
      # characters or underscores).  If it is enclosed in double quotes,
      # any embedded double quotes are doubled up.
      #
      # "jsiracusa                       ".test

      if($item =~ /^(?: "((?:""|[^"]+)+)" | ([^"]+) ) \. (?: "((?:""|[^"]+)+)" | ([^"]+) )$/x)
      {
        my $user  = defined $1 ? $1 : $2;
        my $table = defined $3 ? $3 : $4;

        for($user, $table)
        {
          s/""/"/g;
        }

        next  if($seen{$table}++);

        if(!defined $schema || $schema eq $user)
        {
          push(@tables, $table);
        }
      }
      else
      {
        Carp::carp "Could not parse table information: $item";
      }
    }
  };

  if($@)
  {
    Carp::croak "Could not list tables from ", $self->dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

sub _get_primary_key_column_names
{
  my($self, $catalog, $schema, $table_arg) = @_;

  require DBD::Informix::Metadata;

  my $dbh = $self->dbh or die $self->error;

  local $dbh->{'FetchHashKeyName'} = 'NAME';

  # We need the table owner.  Asking for column information is the only
  # way I know of to reliably get this information.
  #
  # Informix does not support DBI's column_info() method so we have
  # to get all that into "the hard way."
  #
  # Each item in @col_list is a reference to an array of values:
  #
  #   0     owner name
  #   1     table name
  #   2     column number
  #   3     column name
  #   4     data type (encoded)
  #   5     data length (encoded)
  #
  my @col_list = DBD::Informix::Metadata::ix_columns($dbh, $table_arg);

  my $owner = $col_list[0][0];
  my $table = $col_list[0][1]; # just in case...

  unless(defined $owner)
  {
    #die "Could not find owner for table ", $table;

    # Failure to find an owner is sometimes caused by 
    # DBD::Informix::Metadata's annoying habit of returning
    # sequences along with the list of tables.  So we'll just
    # say that it has no primary key columns.
    return [];
  }

  # Then comes this monster query to get the primary key column names.
  # I'd love to know a better/easier way to do this...
  my $pk_sth = $dbh->prepare(<<'EOF');
SELECT 
col.colname
FROM
informix.sysconstraints con, 
informix.systables      tab,
informix.sysindexes     idx,
informix.syscolumns     col
WHERE
 constrtype  = 'P'       AND 
 con.tabid   = tab.tabid AND
 con.tabid   = idx.tabid AND
 con.tabid   = col.tabid AND
 con.idxname = idx.idxname
 AND 
 (
   col.colno = idx.part1  OR
   col.colno = idx.part2  OR
   col.colno = idx.part3  OR
   col.colno = idx.part4  OR
   col.colno = idx.part5  OR
   col.colno = idx.part6  OR
   col.colno = idx.part7  OR
   col.colno = idx.part8  OR
   col.colno = idx.part9  OR
   col.colno = idx.part10 OR
   col.colno = idx.part11 OR
   col.colno = idx.part12 OR
   col.colno = idx.part13 OR
   col.colno = idx.part14 OR
   col.colno = idx.part15 OR
   col.colno = idx.part16
 )
  AND
  tab.tabname = ? AND
  tab.owner   = ?
EOF

  $pk_sth->execute($table, $owner);

  my(@columns, $column);

  $pk_sth->bind_columns(\$column);

  while($pk_sth->fetch)
  {
    push(@columns, $column);
  }

  return \@columns;
}

1;

__END__

=head1 NAME

Rose::DB::Informix - Informix driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db(
    domain   => 'development',
    type     => 'main',
    driver   => 'Informix',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
    server_time_zone => 'UTC',
  );


  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  # Set max length of varchar columns used to emulate the array data type
  Rose::DB::Informix->max_array_characters(128);

  $db = Rose::DB->new; # $db is really a Rose::DB::Informix-derived object

  $dt  = $db->parse_datetime_year_to_minute(...);
  $val = $db->format_datetime_year_to_minute($dt);

  $dt  = $db->parse_datetime_year_to_second(...);
  $val = $db->format_datetime_year_to_second($dt);
  ...

=head1 DESCRIPTION

L<Rose::DB> blesses objects into a class derived from L<Rose::DB::Informix> when the L<driver|Rose::DB/driver> is "informix".  This mapping of driver names to class names is configurable.  See the documentation for L<Rose::DB>'s L<new()|Rose::DB/new> and L<driver_class()|Rose::DB/driver_class> methods for more information.

This class cannot be used directly.  You must use L<Rose::DB> and let its L<new()|Rose::DB/new> method return an object blessed into the appropriate class for you, according to its L<driver_class()|Rose::DB/driver_class> mappings.

Only the methods that are new or have different behaviors than those in L<Rose::DB> are documented here.  See the L<Rose::DB> documentation for the full list of methods.

=head1 CLASS METHODS

=over 4

=item B<max_array_characters [INT]>

Get or set the maximum length of varchar columns used to emulate the array data type.  The default value is 255.

Informix does not have a native "ARRAY" data type, but it can be emulated using a "VARCHAR" column and a specially formatted string.  The formatting and parsing of this string is handled by the C<format_array()> and C<parse_array()> object methods.  The maximum length limit is honored by the C<format_array()> object method.

Informix does have a native "SET" data type, serviced by the C<parse_set()> and C<format_set()> object methods.  This is a better choice than the emulated array data type if you don't care about the order of the stored values.

=back

=head1 OBJECT METHODS

=head2 Value Parsing and Formatting

=over 4

=item B<format_array ARRAYREF | LIST>

Given a reference to an array or a list of values, return a specially formatted string.  Undef is returned if ARRAYREF points to an empty array or if LIST is not passed.  The array or list must not contain undefined values.

If the resulting string is longer than C<max_array_characters()>, a fatal error will occur.

=item B<format_date DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATE" data type.

=item B<format_datetime DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO SECOND" data type.

=item B<format_datetime_year_to_fraction DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO FRACTION" data type.

=item B<format_datetime_year_to_fraction_[1-5] DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO FRACTION(N)" data type, where N is an integer from 1 to 5.

=item B<format_datetime_year_to_minute DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO MINUTE" data type.

=item B<format_datetime_year_to_second DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO SECOND" data type.

=item B<format_set ARRAYREF | LIST>

Given a reference to an array or a list of values, return a string formatted according to the rules of Informix's "SET" data type.  Undef is returned if ARRAYREF points to an empty array or if LIST is not passed.  If th array or list  contains undefined values, a fatal error will occur.

=item B<format_timestamp DATETIME>

Converts the C<DateTime> object DATETIME into the appropriate format for the "DATETIME YEAR TO FRACTION(5)" data type.

=item B<parse_array STRING | LIST | ARRAYREF>

Parse STRING and return a reference to an array.  STRING should be formatted according to the Informix array data type emulation format returned by C<format_array()>.  Undef is returned if STRING is undefined.

If a LIST of more than one item is passed, a reference to an array containing the values in LIST is returned.

If a an ARRAYREF is passed, it is returned as-is.

=item B<parse_boolean STRING>

Parse STRING and return a boolean value of 1 or 0.  STRING should be formatted according to Informix's native "boolean" data type.  Acceptable values are 't', 'T', or '1' for true, and 'f', 'F', or '0' for false.

If STRING is a valid boolean keyword (according to C<validate_boolean_keyword()>) or if it looks like a function call (matches /^\w+\(.*\)$/) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "boolean" value.

=item B<parse_datetime STRING>

Parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO SECOND" data type.

If STRING is a valid "datetime year to second" keyword (according to C<validate_datetime_year_to_second_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO SECOND" value.

=item B<parse_datetime_year_to_fraction STRING>

Parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO FRACTION" data type.

If STRING is a valid "datetime year to fraction" keyword (according to C<validate_datetime_year_to_fraction_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO FRACTION" value.

=item B<parse_datetime_year_to_fraction_[1-5] STRING>

These five methods parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO FRACTION(N)" data type, where N is an integer from 1 to 5.

If STRING is a valid "datetime year to fraction" keyword (according to C<validate_datetime_year_to_fraction_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO FRACTION(N)" value.

=item B<parse_datetime_year_to_minute STRING>

Parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO MINUTE" data type.

If STRING is a valid "datetime year to minute" keyword (according to C<validate_datetime_year_to_minute_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO MINUTE" value.

=item B<parse_datetime_year_to_second STRING>

Parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO SECOND" data type.

If STRING is a valid "datetime year to second" keyword (according to C<validate_datetime_year_to_second_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO SECOND" value.

=item B<parse_set STRING | LIST | ARRAYREF>

Parse STRING and return a reference to an array.  STRING should be formatted according to Informix's "SET" data type.  Undef is returned if STRING is undefined.

If a LIST of more than one item is passed, a reference to an array containing the values in LIST is returned.

If a an ARRAYREF is passed, it is returned as-is.

=item B<parse_timestamp STRING>

Parse STRING and return a C<DateTime> object.  STRING should be formatted according to the Informix "DATETIME YEAR TO FRACTION(5)" data type.

If STRING is a valid timestamp keyword (according to C<validate_timestamp_keyword()>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "DATETIME YEAR TO FRACTION(5)" value.

=item B<validate_date_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "date", false otherwise.   Valid date keywords are:

    current
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid date keyword.

=item B<validate_datetime_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "datetime year to second" data type, false otherwise.  Valid datetime keywords are:

    current
    current year to second
    current year to minute
    current year to hour
    current year to day
    current year to month
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid datetime keyword.

=item B<validate_datetime_year_to_fraction_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "datetime year to fraction(n)" data type (where n is an integer from 1 to 5), false otherwise.  Valid "datetime year to fraction" keywords are:

    current
    current year to fraction
    current year to fraction(1)
    current year to fraction(2)
    current year to fraction(3)
    current year to fraction(4)
    current year to fraction(5)
    current year to second
    current year to minute
    current year to hour
    current year to day
    current year to month
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid "datetime year to fraction" keyword.

=item B<validate_datetime_year_to_minute_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "datetime year to minute" data type, false otherwise.  Valid "datetime year to minute" keywords are:

    current
    current year to minute
    current year to hour
    current year to day
    current year to month
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid "datetime year to minute" keyword.

=item B<validate_datetime_year_to_second_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "datetime year to second" data type, false otherwise.  Valid datetime keywords are:

    current
    current year to second
    current year to minute
    current year to hour
    current year to day
    current year to month
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid "datetime year to second" keyword.

=item B<validate_timestamp_keyword STRING>

Returns true if STRING is a valid keyword for the Informix "timestamp" data type, false otherwise.  Valid timestamp keywords are:

    current
    current year to fraction
    current year to fraction(1)
    current year to fraction(2)
    current year to fraction(3)
    current year to fraction(4)
    current year to fraction(5)
    current year to second
    current year to minute
    current year to hour
    current year to day
    current year to month
    today

The keywords are not case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid timestamp keyword.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
