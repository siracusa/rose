#!/usr/bin/perl -w

use strict;

use Test::More tests => 1 + (4 * 12);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::Loader');
}

our %Have;

our @Tables = qw(vendors products prices colors products_colors);
our $Include_Tables = join('|', @Tables);

#
# Tests
#

my $i = 1;

foreach my $db_type (qw(mysql pg pg_with_schema informix))
{
  SKIP:
  {
    skip("$db_type tests", 12)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  $i++;

  Rose::DB->default_type($db_type);
  Rose::DB::Object::Metadata->unregister_all_classes;

  my $class_prefix = ucfirst($db_type eq 'pg_with_schema' ? 'pgws' : $db_type);

  #$Rose::DB::Object::Metadata::Debug = 1;

  my $loader = 
    Rose::DB::Object::Loader->new(
      db           => Rose::DB->new,
      class_prefix => $class_prefix);
  
  my @classes = $loader->make_classes(include_tables => $Include_Tables);

  if($db_type eq 'informix')
  {
    foreach my $class (@classes)
    {
      next  unless($class->isa('Rose::DB::Object'));
      $class->meta->allow_inline_column_values(1);
    }
  }

  my $product_class = $class_prefix . '::Product';

  ##
  ## Run tests
  ##

  my $p = $product_class->new(name => "Sled $i");

  is($p->db->class, 'Rose::DB', "db 1 - $db_type");
  
  OBJECT_CLASS:
  {
    no strict 'refs';
    ok(${"${product_class}::ISA"}[0] =~ /^${class_prefix}::DB::Object::Base\d+$/, "base class 1 - $db_type");
  }

  $p->vendor(name => "Acme $i");

  $p->prices({ price => 1.23, region => 'US' },
             { price => 4.56, region => 'UK' });

  $p->colors({ name => 'red'   }, 
             { name => 'green' });

  $p->save;
  
  $p = $product_class->new(id => $p->id)->load;
  is($p->vendor->name, "Acme $i", "vendor 1 - $db_type");

  
  my @prices = sort { $a->price <=> $b->price } $p->prices;
  
  is(scalar @prices, 2, "prices 1 - $db_type");
  is($prices[0]->price, 1.23, "prices 2 - $db_type");
  is($prices[1]->price, 4.56, "prices 3 - $db_type");

  my @colors = sort { $a->name cmp $b->name } $p->colors;
  
  is(scalar @colors, 2, "colors 1 - $db_type");
  is($colors[0]->name, 'green', "colors 2 - $db_type");
  is($colors[1]->name, 'red', "colors 3 - $db_type");

  my $mgr_class = $class_prefix . '::Product::Manager';
  my $prods = $mgr_class->get_products(query => [ id => $p->id ]);
  
  is(ref $prods, 'ARRAY', "get_products 1 - $db_type");
  is(@$prods, 1, "get_products 2 - $db_type");
  is($prods->[0]->id, $p->id, "get_products 3 - $db_type");

  #$DB::single = 1;
  #$Rose::DB::Object::Debug = 1;
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

      $dbh->do('DROP TABLE products_colors CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    
      $dbh->do('DROP TABLE Rose_db_object_private.products_colors CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.colors CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.prices CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.products CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.vendors CASCADE');
    
      $dbh->do('DROP SCHEMA Rose_db_object_private CASCADE');
      $dbh->do('CREATE SCHEMA Rose_db_object_private');
    }

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  vendor_id  INT REFERENCES vendors (id),

  status  VARCHAR(128) NOT NULL DEFAULT 'inactive' 
            CHECK(status IN ('inactive', 'active', 'defunct')),

  date_created  TIMESTAMP NOT NULL DEFAULT NOW(),
  release_date  TIMESTAMP,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products_colors
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  vendor_id  INT REFERENCES vendors (id),

  status  VARCHAR(128) NOT NULL DEFAULT 'inactive' 
            CHECK(status IN ('inactive', 'active', 'defunct')),

  date_created  TIMESTAMP NOT NULL DEFAULT NOW(),
  release_date  TIMESTAMP,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.colors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.products_colors
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
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

    my $version = $dbh->get_info(18); # SQL_DBMS_VER  

    die "MySQL version too old"  unless($version =~ /^4\./);

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE products_colors CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }

    # Foreign key stuff requires InnoDB support
    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    # MySQL will silently ignore the "TYPE=InnoDB" part and create
    # a MyISAM table instead.  MySQL is evil!  Now we have to manually
    # check to make sure an InnoDB table was really created.
    my $db_name = $db->database;
    my $sth = $dbh->prepare("SHOW TABLE STATUS FROM `$db_name` LIKE ?");
    $sth->execute('vendors');
    my $info = $sth->fetchrow_hashref;

    unless(lc $info->{'Type'} eq 'innodb' || lc $info->{'Engine'} eq 'innodb')
    {
      die "Missing InnoDB support";
    }
  };

  if(!$@ && $dbh)
  {
    $Have{'mysql'} = 1;

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  vendor_id  INT,

  status  VARCHAR(128) NOT NULL DEFAULT 'inactive' 
            CHECK(status IN ('inactive', 'active', 'defunct')),

  date_created  TIMESTAMP,
  release_date  TIMESTAMP,

  UNIQUE(name),
  INDEX(vendor_id),

  FOREIGN KEY (vendor_id) REFERENCES vendors (id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL,
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region),
  INDEX(product_id),

  FOREIGN KEY (product_id) REFERENCES products (id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products_colors
(
  product_id  INT NOT NULL,
  color_id    INT NOT NULL,

  PRIMARY KEY(product_id, color_id),

  INDEX(color_id),
  INDEX(product_id),

  FOREIGN KEY (product_id) REFERENCES products (id),
  FOREIGN KEY (color_id) REFERENCES colors (id)
)
TYPE=InnoDB
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

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE products_colors CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  price   DECIMAL(10,2) DEFAULT 0.00 NOT NULL,

  vendor_id  INT REFERENCES vendors (id),

  status  VARCHAR(128) DEFAULT 'inactive' NOT NULL
            CHECK(status IN ('inactive', 'active', 'defunct')),

  date_created  DATETIME YEAR TO SECOND,
  release_date  DATETIME YEAR TO SECOND,
  
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) DEFAULT 'US' NOT NULL,
  price       DECIMAL(10,2) DEFAULT 0.00 NOT NULL,

  UNIQUE(product_id, region)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products_colors
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
)
EOF

    $dbh->commit;
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

    $dbh->do('DROP TABLE products_colors CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->do('DROP TABLE Rose_db_object_private.products_colors CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.colors CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.prices CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.products CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.vendors CASCADE');

    $dbh->do('DROP SCHEMA Rose_db_object_private CASCADE');
      
    $dbh->disconnect;
  }

  if($Have{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE products_colors CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($Have{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE products_colors CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }
}
