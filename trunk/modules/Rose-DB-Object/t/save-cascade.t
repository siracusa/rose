#!/usr/bin/perl -w

use strict;

use Test::More tests => 5;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::Loader');
}

our %Have;

#
# Tests
#

#$Rose::DB::Object::Manager::Debug = 1;

foreach my $db_type (qw(mysql pg informix sqlite))
{
  SKIP:
  {
    skip("$db_type tests", 1)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  my $class_prefix =  ucfirst($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
      db           => Rose::DB->new,
      class_prefix => $class_prefix);

  my @classes = $loader->make_classes(include_tables => 
    '^(?:products|prices|colors|vendors|product_colors)$');

  #foreach my $class (@classes)
  #{
  #  print $class->meta->perl_class_definition if($class->can('meta'));
  #}

  my $product_class = $class_prefix . '::Product';
  my $vendor_class  = $class_prefix . '::Vendor';

  my $p = $product_class->new(name => 'p1', vendor => { name => 'v1' });
  $p->save;

  $p = $product_class->new(id => $p->id)->load;
  
  my $v = $p->vendor;
  $v->name('v1.1');
  $p->save(cascade => 1);

  $v = $vendor_class->new(id => $v->id)->load;
  is($v->name, 'v1.1', "cascade fk 1 - $db_type");
}

BEGIN
{
  our %Have;

  #
  # Postgres
  #

  my $dbh;

  eval 
  {
    $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have{'pg'} = 1;
    $Have{'pg_with_schema'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE product_colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }

  #
  # MySQL
  #

  eval 
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh or die Rose::DB->error;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE product_colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }
  };

  if(!$@ && $dbh)
  {
    $Have{'mysql'} = 1;

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           INT AUTO_INCREMENT PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }

  #
  # Informix
  #

  eval
  {
    $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have{'informix'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE product_colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }

  #
  # SQLite
  #

  eval
  {
    $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have{'sqlite'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE product_colors');
      $dbh->do('DROP TABLE prices');
      $dbh->do('DROP TABLE products');
      $dbh->do('DROP TABLE colors');
      $dbh->do('DROP TABLE vendors');
    }

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }
}

END
{
  # Delete test table

  if($Have{'pg'})
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($Have{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($Have{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($Have{'sqlite'})
  {
    # Informix
    my $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors');
    $dbh->do('DROP TABLE prices');
    $dbh->do('DROP TABLE products');
    $dbh->do('DROP TABLE colors');
    $dbh->do('DROP TABLE vendors');

    $dbh->disconnect;
  }
}
