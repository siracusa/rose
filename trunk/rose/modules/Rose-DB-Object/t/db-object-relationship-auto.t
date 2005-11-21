#!/usr/bin/perl -w

use strict;

my $Iterations;

BEGIN { $Iterations = 2 }
use Test::More tests => 2 + (4 * 9 * $Iterations);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

our %Have;

#
# Setup
#

# Some good test cases:
#@Classes = qw(Color Price ProductsColors Vendor Product);
#@Classes = qw(Price ProductsColors Product Color Vendor);
#@Classes = qw(ProductsColors Price Vendor Product Color);
#@Classes = qw(Price Color Vendor ProductsColors Product)
my @Classes = qw(Vendor Product Price Color ProductsColors);

eval { require List::Util };
my $Can_Shuffle = $@ ? 0 : 1;

my %Tables =
(
  Vendor  => 'vendors',
  Product => 'products',
  Price   => 'prices',
  Color   => 'colors',
  ProductsColors => 'products_colors',
);

my %Setup_Class;

#
# Tests
#

foreach my $i (1 .. $Iterations)
{
  foreach my $db_type (qw(mysql pg pg_with_schema informix))
  {
    SKIP:
    {
      skip("$db_type tests", 9)  unless($Have{$db_type});
    }
  
    next  unless($Have{$db_type});
  
    Rose::DB->default_type($db_type);
    Rose::DB::Object::Metadata->unregister_all_classes;

    my $class_prefix = ucfirst($db_type eq 'pg_with_schema' ? 'pg' : $db_type) . $i;

    @Classes = List::Util::shuffle(@Classes)  if($Can_Shuffle);
    print "# Class order: @Classes\n";

    #$Rose::DB::Object::Metadata::Debug = 1;

    foreach my $class_root (@Classes)
    {
      my $class = $class_prefix . $class_root;
  
      if($Setup_Class{$class}++)
      {
        #$class->meta->init_with_db(Rose::DB->new);
      }
      else
      {   
        no strict 'refs';
        @{"${class}::ISA"} = qw(Rose::DB::Object);
        $class->meta->table($Tables{$class_root});
        #$class->meta->init_with_db(Rose::DB->new);
        $class->meta->auto_initialize;
      }
    }

    my $product_class = $class_prefix . 'Product';

    ##
    ## Run tests
    ##
  
    my $p = $product_class->new(name => "Sled $i");
  
    $p->vendor(name => "Acme $i");
  
    $p->prices({ price => 1.23, region => 'US' },
               { price => 4.56, region => 'UK' });
  
    $p->colors({ name => 'red'   }, 
               { name => 'green' });
  
    $p->save;
    
    $p = $product_class->new(id => $p->id)->load;
    is($p->vendor->name, "Acme $i", "vendor $i.1 - $db_type");
  
    
    my @prices = sort { $a->price <=> $b->price } $p->prices;
    
    is(scalar @prices, 2, "prices $i.1 - $db_type");
    is($prices[0]->price, 1.23, "prices $i.2 - $db_type");
    is($prices[1]->price, 4.56, "prices $i.3 - $db_type");
  
    my @colors = sort { $a->name cmp $b->name } $p->colors;
    
    is(scalar @colors, 2, "colors $i.1 - $db_type");
    is($colors[0]->name, 'green', "colors $i.2 - $db_type");
    is($colors[1]->name, 'red', "colors $i.3 - $db_type");
  
    #$DB::single = 1;
    #$Rose::DB::Object::Debug = 1;
 
    #
    # Test code generation
    #
  
    is($product_class->meta->perl_relationships_definition,
       <<"EOF", "perl_relationships_definition $i.1 - $db_type");
__PACKAGE__->meta->relationships(
    colors => {
        column_map    => { product_id => 'id' },
        foreign_class => '${class_prefix}Color',
        map_class     => '${class_prefix}ProductsColors',
        map_from      => 'product',
        map_to        => 'color',
        type          => 'many to many',
    },

    prices => {
        class       => '${class_prefix}Price',
        key_columns => { id => 'product_id' },
        type        => 'one to many',
    },
);
EOF

    is($product_class->meta->perl_relationships_definition(braces => 'bsd', indent => 2),
       <<"EOF", "perl_relationships_definition $i.2 - $db_type");
__PACKAGE__->meta->relationships
(
  colors => 
  {
    column_map    => { product_id => 'id' },
    foreign_class => '${class_prefix}Color',
    map_class     => '${class_prefix}ProductsColors',
    map_from      => 'product',
    map_to        => 'color',
    type          => 'many to many',
  },

  prices => 
  {
    class       => '${class_prefix}Price',
    key_columns => { id => 'product_id' },
    type        => 'one to many',
  },
);
EOF

    $product_class->meta_class->clear_all_dbs;
  }
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
