package Rose::DB::Oracle;

use strict;

use SQL::ReservedWords::Oracle();

use Rose::DB;

our $Debug = 0;

# Overshot distribution version, so freeze until it catches up
our $VERSION  = '0.73'; 

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

  my($version) = $self -> dbh -> get_info(18); # SQL_DBMS_VER.

  # Convert to an integer, e.g., 10.02.0100 -> 100020100

  if ($version =~ /^(\d+)\.(\d+)(?:\.(\d+))?/)
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
    my($dbh) = $self -> dbh or die $self -> error;

    local $dbh->{'RaiseError'} = 1;
    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my($sth)  = $dbh -> table_info($self -> catalog, $self -> schema, '%', $types);
    my($info) = $sth -> fetchall_arrayref({}); # The {} are mandatory.

    for my $table (@$info)
    {
      push @tables, $$table{'TABLE_NAME'} if ($$table{'TABLE_NAME'} !~ /^BIN\$.+\$.+/);
    }
  };

  if($@)
  {
    Carp::croak 'Could not list tables from ', $self -> dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

sub next_value_in_sequence
{
  my($self, $seq) = @_;
  my($dbh)        = $self -> dbh or return undef;

  my $id;

  eval
  {
    my($sth) = $dbh -> prepare("SELECT $seq.nextval from dual");

    $sth -> execute($seq);

    $id = ${$sth -> fetch()}[0];

    $sth -> finish();
  };

  if ($@)
  {
    $self -> error("Could not get the next value in the sequence '$seq' - $@");

    return undef;
  }

  return $id;
}

*is_reserved_word = \&SQL::ReservedWords::Oracle::is_reserved;

sub supports_schema { 1 }

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

B<Note:> this class is a work in progress.  Support for Oracle databases is not yet complete.  If you would like to help, please contact John Siracusa at siracusa@mindspring.com or post to the L<mailing list|Rose::DB/SUPPORT>.

L<Rose::DB> blesses objects into a class derived from L<Rose::DB::Oracle> when the L<driver|Rose::DB/driver> is "oracle".  This mapping of driver names to class names is configurable.  See the documentation for L<Rose::DB>'s L<new()|Rose::DB/new> and L<driver_class()|Rose::DB/driver_class> methods for more information.

This class cannot be used directly.  You must use L<Rose::DB> and let its L<new()|Rose::DB/new> method return an object blessed into the appropriate class for you, according to its L<driver_class()|Rose::DB/driver_class> mappings.

Only the methods that are new or have different behaviors than those in L<Rose::DB> are documented here.  See the L<Rose::DB> documentation for the full list of methods.

=head1 AUTHOR

Ron Savage <ron@savage.net.au>

http://savage.net.au/index.html

=head1 COPYRIGHT

Copyright (c) 2006 by Ron Savage. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
