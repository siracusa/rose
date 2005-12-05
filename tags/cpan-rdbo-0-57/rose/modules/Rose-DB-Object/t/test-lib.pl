#!/usr/bin/perl

use strict;

use FindBin qw($Bin);

use Rose::DB;

BEGIN 
{  
  Rose::DB->default_domain('test');

  #
  # Postgres
  #

  # Main
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'pg',
    driver   => 'Pg',
    database => 'test',
    host     => 'localhost',
    username => 'postgres',
    password => '',
    connect_options => { AutoCommit => 1 },
    post_connect_sql =>
    [
      'SET default_transaction_isolation TO "read committed"',
    ],
  );

  # Private schema
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'pg_with_schema',
    schema   => 'rose_db_object_private',
    driver   => 'Pg',
    database => 'test',
    host     => 'localhost',
    username => 'postgres',
    password => '',
    connect_options => { AutoCommit => 1 },
    post_connect_sql =>
    [
      'SET default_transaction_isolation TO "read committed"',
    ],
  );

  # Admin
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'pg_admin',
    driver   => 'Pg',
    database => 'test',
    host     => 'localhost',
    username => 'postgres',
    password => '',
    connect_options => { AutoCommit => 1 },
    post_connect_sql =>
    [
      'SET default_transaction_isolation TO "read committed"',
    ],
  );

  #
  # MySQL
  #

  # Main
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'mysql',
    driver   => 'mysql',
    database => 'test',
    host     => 'localhost',
    username => 'root',
    password => ''
  );

  # Admin
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'mysql_admin',
    driver   => 'mysql',
    database => 'test',
    host     => 'localhost',
    username => 'root',
    password => ''
  );

  #
  # Informix
  #

  # Main
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'informix',
    driver   => 'Informix',
    database => 'test@test',
    connect_options => { AutoCommit => 1 },
    post_connect_sql =>
    [
      'SET LOCK MODE TO WAIT 100',
      'SET ISOLATION TO DIRTY READ',
    ],
  );

  # Admin
  Rose::DB->register_db(
    domain   => 'test',
    type     => 'informix_admin',
    driver   => 'Informix',
    database => 'test@test',
    connect_options => { AutoCommit => 1 },
    post_connect_sql =>
    [
      'SET LOCK MODE TO WAIT 100',
      'SET ISOLATION TO DIRTY READ',
    ],
  );

  #
  # SQLite
  #

  eval { require DBD::SQLite };

  my $version = $DBD::SQLite::VERSION || 0;

  unless($ENV{'RDBO_NO_SQLITE'} || $version < 1.08)
  {
    # Main
    Rose::DB->register_db(
      domain   => 'test',
      type     => 'sqlite',
      driver   => 'sqlite',
      database => "$Bin/sqlite.db",
      auto_create     => 0,
      connect_options => { AutoCommit => 1 },
    );

    # Admin
    Rose::DB->register_db(
      domain   => 'test',
      type     => 'sqlite_admin',
      driver   => 'sqlite',
      database => "$Bin/sqlite.db",
      connect_options => { AutoCommit => 1 },
    );
  }

  my @types = qw(pg pg_with_schema pg_admin mysql mysql_admin 
                 informix informix_admin);

  unless($Rose::DB::Object::Test::NoDefaults)
  {
    foreach my $db_type (qw(PG MYSQL INFORMIX))
    {
      if(my $dsn = $ENV{"RDBO_${db_type}_DSN"})
      {
        foreach my $type (grep { /^$db_type(?:_|$)/i } @types)
        {
          Rose::DB->modify_db(domain => 'test', type => $type, dsn => $dsn);
        }
      }

      if(my $user = $ENV{"RDBO_${db_type}_USER"})
      {
        foreach my $type (grep { /^$db_type(?:_|$)/i } @types)
        {
          Rose::DB->modify_db(domain => 'test', type => $type, username => $user);
        }
      }

      if(my $user = $ENV{"RDBO_${db_type}_PASS"})
      {
        foreach my $type (grep { /^$db_type(?:_|$)/i } @types)
        {
          Rose::DB->modify_db(domain => 'test', type => $type, password => $user);
        }
      }
    }
  }
}

1;
