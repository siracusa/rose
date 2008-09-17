package Rose::DB::Oracle;

use strict;

use SQL::ReservedWords::Oracle();

use Rose::DB;

our $Debug = 0;

our $VERSION  = '0.746'; 

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => '_default_post_connect_sql',
);

__PACKAGE__->_default_post_connect_sql
(
  [
    q(ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'),
    q(ALTER SESSION SET NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SSxFF'),
    q(ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SSxFF')
  ]
);

sub default_post_connect_sql
{
  my($class) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      $class->_default_post_connect_sql(@_);
    }
    else
    {
      $class->_default_post_connect_sql([ @_ ]);
    }
  }

  return $class->_default_post_connect_sql;
}

sub post_connect_sql
{
  my($self) = shift;

  unless(@_)
  {
    return wantarray ? 
      ( @{ $self->default_post_connect_sql || [] }, @{$self->{'post_connect_sql'} || [] } ) :
      [ @{ $self->default_post_connect_sql || [] }, @{$self->{'post_connect_sql'} || [] } ];
  }

  if(@_ == 1 && ref $_[0] eq 'ARRAY')
  {
    $self->{'post_connect_sql'} = $_[0];
  }
  else
  {
    $self->{'post_connect_sql'} = [ @_ ];
  }

  return wantarray ? 
    ( @{ $self->default_post_connect_sql || [] }, @{$self->{'post_connect_sql'} || [] } ) :
    [ @{ $self->default_post_connect_sql || [] }, @{$self->{'post_connect_sql'} || [] } ];
}

sub schema
{
  my($self) = shift;
  $self->{'schema'} = shift  if(@_);
  return $self->{'schema'} || $self->username;
}

sub use_auto_sequence_name { 1 }

sub auto_sequence_name
{
  my($self, %args) = @_;
  my($table)       = $args{'table'};

  Carp::croak 'Missing table argument' unless(defined $table);

  my($column) = $args{'column'};

  Carp::croak 'Missing column argument' unless(defined $column);

  return lc "${table}_${column}_seq";
}

sub build_dsn
{
  my($self_or_class, %args) = @_;

  my $database = $args{'db'} || $args{'database'};

  if(my $host = $args{'host'})
  {
    return "dbi:Oracle:sid=$database;host=$host";
  }

  return "dbi:Oracle:$database";
}

sub database_version
{
  my($self) = shift;

  return $self->{'database_version'} if (defined $self->{'database_version'});

  my($version) = $self->dbh->get_info(18); # SQL_DBMS_VER.

  # Convert to an integer, e.g., 10.02.0100 -> 100020100

  if($version =~ /^(\d+)\.(\d+)(?:\.(\d+))?/)
  {
    $version = sprintf('%d%03d%04d', $1, $2, $3);
  }

  return $self->{'database_version'} = $version;
}

sub dbi_driver { 'Oracle' }

sub list_tables
{
  my($self, %args) = @_;
  my($types)       = $args{'include_views'} ? "'TABLE','VIEW'" : 'TABLE';

  my @tables;

  eval
  {
    my($dbh) = $self->dbh or die $self->error;

    local $dbh->{'RaiseError'} = 1;
    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $sth  = $dbh->table_info($self->catalog, uc $self->schema, '%', $types);
    my $info = $sth->fetchall_arrayref({}); # The {} are mandatory.

    for my $table (@$info)
    {
      push @tables, $$table{'TABLE_NAME'} if ($$table{'TABLE_NAME'} !~ /^BIN\$.+\$.+/);
    }
  };

  if($@)
  {
    Carp::croak 'Could not list tables from ', $self->dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

sub next_value_in_sequence
{
  my($self, $seq) = @_;
  my($dbh)        = $self->dbh or return undef;

  my $id;

  eval
  {
    my($sth) = $dbh->prepare("SELECT $seq.nextval FROM dual");

    $sth->execute;

    $id = ${$sth->fetch}[0];

    $sth->finish;
  };

  if ($@)
  {
    $self->error("Could not get the next value in the sequence '$seq' - $@");

    return undef;
  }

  return $id;
}

*is_reserved_word = \&SQL::ReservedWords::Oracle::is_reserved;

sub quote_identifier_for_sequence
{
  my($self, $catalog, $schema, $table) = @_;
  return join('.', grep { defined } ($schema, $table));
}

sub supports_schema { 1 }

sub primary_key_column_names
{
  my($self) = shift;

  my %args = @_ == 1 ? (table => @_) : @_;

  my $table   = $args{'table'} or Carp::croak "Missing table name parameter";
  my $schema  = $args{'schema'} || $self->schema;
  my $catalog = $args{'catalog'} || $self->catalog;

  $table   = uc $table;
  $schema  = uc $schema;
  $catalog = uc $catalog;

  my $table_unquoted = $self->unquote_table_name($table);

  my $columns;

  eval 
  {
    $columns = 
      $self->_get_primary_key_column_names($catalog, $schema, $table_unquoted);
  };

  if($@ || !$columns)
  {
    no warnings 'uninitialized'; # undef strings okay
    $@ = 'no primary key columns found'  unless(defined $@);
    Carp::croak "Could not get primary key columns for catalog '" . 
                $catalog . "' schema '" . $schema . "' table '" . 
                $table_unquoted . "' - " . $@;
  }

  return wantarray ? @$columns : $columns;
}

sub format_limit_with_offset
{
  my($self, $limit, $offset, $args) = @_;

  delete $args->{'limit'};
  delete $args->{'offset'};

  if($offset)
  {
    # http://www.oracle.com/technology/oramag/oracle/06-sep/o56asktom.html
    # select * 
    #   from ( select /*+ FIRST_ROWS(n) */ 
    #   a.*, ROWNUM rnum 
    #       from ( your_query_goes_here, 
    #       with order by ) a 
    #       where ROWNUM <= 
    #       :MAX_ROW_TO_FETCH ) 
    # where rnum  >= :MIN_ROW_TO_FETCH;

    my $size  = $limit;
    my $start = $offset + 1;
    my $end   = $start + $size - 1;
    my $n     = $offset + $limit;

    $args->{'limit_prefix'} = 
      "SELECT * FROM (SELECT /*+ FIRST_ROWS($n) */\na.*, ROWNUM oracle_rownum FROM (";
      #"SELECT * FROM (SELECT a.*, ROWNUM oracle_rownum FROM (";

    $args->{'limit_suffix'} = 
      ") a WHERE ROWNUM <= $end) WHERE oracle_rownum >= $start";
  }
  else
  {
    $args->{'limit_prefix'} = "SELECT /*+ FIRST_ROWS($limit) */ a.* FROM (";
    #$args->{'limit_prefix'} = "SELECT a.* FROM (";
    $args->{'limit_suffix'} = ") a WHERE ROWNUM <= $limit";
  }
}

sub format_boolean { $_[1] ? 't' : 'f' }

#
# Date/time keywords and inlining
#

# XXX: Guesswork!  Oracle users, patches welcome!

sub validate_date_keyword
{
  no warnings;
  $_[1] =~ /^(?:(?:CURRENT_|SYS)(?:TIMESTAMP|DATE)|\w+\(.*\))$/i;
}

*validate_time_keyword      = \&validate_date_keyword;
*validate_timestamp_keyword = \&validate_date_keyword;
*validate_datetime_keyword  = \&validate_date_keyword;

sub should_inline_date_keywords      { 1 }
sub should_inline_datetime_keywords  { 1 }
sub should_inline_time_keywords      { 1 }
sub should_inline_timestamp_keywords { 1 }

1;

__END__

=head1 NAME

Rose::DB::Oracle - Oracle driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db
  (
    domain   => 'development',
    type     => 'main',
    driver   => 'Oracle',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
  );

  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  $db = Rose::DB->new; # $db is really a Rose::DB::Oracle-derived object
  ...

=head1 DESCRIPTION

L<Rose::DB> blesses objects into a class derived from L<Rose::DB::Oracle> when the L<driver|Rose::DB/driver> is "oracle".  This mapping of driver names to class names is configurable.  See the documentation for L<Rose::DB>'s L<new()|Rose::DB/new> and L<driver_class()|Rose::DB/driver_class> methods for more information.

This class cannot be used directly.  You must use L<Rose::DB> and let its L<new()|Rose::DB/new> method return an object blessed into the appropriate class for you, according to its L<driver_class()|Rose::DB/driver_class> mappings.

Only the methods that are new or have different behaviors than those in L<Rose::DB> are documented here.  See the L<Rose::DB> documentation for the full list of methods.

B<Oracle 9 or later is required.>

B<Note:> This class is a work in progress.  Support for Oracle databases is not yet complete.  If you would like to help, please contact John Siracusa at siracusa@gmail.com or post to the L<mailing list|Rose::DB/SUPPORT>.

=head1 CLASS METHODS

=over 4

=item B<default_post_connect_sql [STATEMENTS]>

Get or set the default list of SQL statements that will be run immediately after connecting to the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to the array of SQL statements in scalar context, or a list of SQL statements in list context.

The L<default_post_connect_sql|/default_post_connect_sql> statements will be run before any statements set using the L<post_connect_sql|/post_connect_sql> method.  The default list contains the following:

    ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'
    ALTER SESSION SET NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SSxFF'
    ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SSxFF'

These statements enable date/time column value parsing and formatting to work correctly.

=back

=head1 OBJECT METHODS

=over 4

=item B<post_connect_sql [STATEMENTS]>

Get or set the SQL statements that will be run immediately after connecting to the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to an array (in scalar) or a list of the L<default_post_connect_sql|/default_post_connect_sql> statements and the L<post_connect_sql|/post_connect_sql> statements.  Example:

    $db->post_connect_sql('UPDATE mytable SET num = num + 1');

    print join("\n", $db->post_connect_sql);

    ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'
    ALTER SESSION SET NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SSxFF'
    UPDATE mytable SET num = num + 1

=item B<schema [SCHEMA]>

Get or set the database schema name.  In Oracle, every user has a corresponding schema.  The schema is comprised of all objects that user owns, and has the same name as that user.  Therefore, this attribute defaults to the L<username|Rose::DB/username> if it is not set explicitly.

=back

=head1 AUTHORS

John C. Siracusa (siracusa@gmail.com), Ron Savage (ron@savage.net.au)

=head1 COPYRIGHT

Copyright (c) 2008 by John Siracusa and Ron Savage.  All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
