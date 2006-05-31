#!/usr/bin/perl -w

use strict;

use Test::More();

my $Lib_Dir = 't/cg-lib';

unless(-d $Lib_Dir)
{
  mkdir($Lib_Dir);
}

if(-d $Lib_Dir)
{
  Test::More->import(tests => 7);
}
else
{
  Test::More->import(skip_all => "Could not mkdir($Lib_Dir) - $!");
}

require 't/test-lib.pl';
use_ok('Rose::DB::Object');
use_ok('Rose::DB::Object::Loader');

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL_WITH_INNODB, $HAVE_INFORMIX, 
    $HAVE_SQLITE);

my $Include_Tables = '^(?:' . join('|', 
  qw(product_colors prices products colors vendors)) . ')$';
$Include_Tables = qr($Include_Tables);

#
# Postgres
#

SKIP: foreach my $db_type ('pg')
{
  skip("Postgres tests", 2)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
    db_class     => 'Rose::DB',
    class_prefix => 'MyPg::',
    include_tables => $Include_Tables);

  $loader->make_modules(module_dir   => $Lib_Dir,
                        braces       => 'bsd',
                        indent       => 2);
  
  is(slurp("$Lib_Dir/MyPg/Product.pm"), <<"EOF", "Product 1 - $db_type");
package MyPg::Product;

use strict;

use base qw(MyPg::DB::Object::AutoBase1);

__PACKAGE__->meta->setup
(
  table   => 'products',

  columns => 
  [
    id        => { type => 'serial', not_null => 1 },
    name      => { type => 'varchar', length => 255 },
    vendor_id => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  unique_keys => 
  [
    [ 'name', 'vendor_id' ],
    [ 'name' ],
  ],

  foreign_keys => 
  [
    vendor => 
    {
      class => 'MyPg::Vendor',
      key_columns => 
      {
        vendor_id => 'id',
      },
    },
  ],

  relationships => 
  [
    colors => 
    {
      column_map    => { product_id => 'id' },
      foreign_class => 'MyPg::Color',
      map_class     => 'MyPg::ProductColor',
      map_from      => 'product',
      map_to        => 'color',
      type          => 'many to many',
    },
  
    prices => 
    {
      class       => 'MyPg::Price',
      key_columns => { id => 'product_id' },
      type        => 'one to many',
    },
  ],
);

1;

EOF

  is(slurp("$Lib_Dir/MyPg/Color.pm"), <<"EOF", "Color 1 - $db_type");
package MyPg::Color;

use strict;

use base qw(MyPg::DB::Object::AutoBase1);

__PACKAGE__->meta->setup
(
  table   => 'colors',

  columns => 
  [
    code => { type => 'character', length => 3, not_null => 1 },
    name => { type => 'varchar', length => 255 },
  ],

  primary_key_columns => [ 'code' ],

  unique_keys => [ 'name' ],

  relationships => 
  [
    products => 
    {
      column_map    => { color_code => 'code' },
      foreign_class => 'MyPg::Product',
      map_class     => 'MyPg::ProductColor',
      map_from      => 'color',
      map_to        => 'product',
      type          => 'many to many',
    },
  ],
);

1;

EOF

  unshift(@INC, $Lib_Dir);

  # XXX: Test actual code by running external script with db type arg

  shift(@INC);
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 1)  unless($HAVE_MYSQL_WITH_INNODB);

  Rose::DB->default_type($db_type);
}

#
# Informix
#

SKIP: foreach my $db_type ('informix')
{
  skip("Informix tests", 1)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);
}

#
# SQLite
#

SKIP: foreach my $db_type ('sqlite')
{
  skip("SQLite tests", 1)  unless($HAVE_SQLITE);

  Rose::DB->default_type($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
    class_prefix => 'MySQLite::');

  $loader->make_modules(module_dir   => $Lib_Dir,
                        braces       => 'bsd',
                        indent       => 2);
}

BEGIN
{
  require 't/test-lib.pl';

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
    our $HAVE_PG = 1;

    #Rose::DB::Object::Metadata->unregister_all_classes;

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

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL NOT NULL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),
  
  UNIQUE(name, vendor_id),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL NOT NULL PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }

  #
  # MySQL
  #

  my $db_version;

  eval
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh or die Rose::DB->error;
    $db_version = $db->database_version;

    die "MySQL version too old"  unless($db_version >= 4_000_000);

    CLEAR:
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE product_colors CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
    }

    # Foreign key stuff requires InnoDB support
    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
TYPE=InnoDB
EOF

    # MySQL will silently ignore the "TYPE=InnoDB" part and create
    # a MyISAM table instead.  MySQL is evil!  Now we have to manually
    # check to make sure an InnoDB table was really created.
    my $db_name = $db->database;
    my $sth = $dbh->prepare("SHOW TABLE STATUS FROM `$db_name` LIKE ?");
    $sth->execute('Rose_db_object_other');
    my $info = $sth->fetchrow_hashref;

    unless(lc $info->{'Type'} eq 'innodb' || lc $info->{'Engine'} eq 'innodb')
    {
      die "Missing InnoDB support";
    }
  };

  if(!$@ && $dbh)
  {
    our $HAVE_MYSQL_WITH_INNODB = 1;

    #Rose::DB::Object::Metadata->unregister_all_classes;

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255),
  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL NOT NULL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),
  
  UNIQUE(name, vendor_id),
  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL NOT NULL PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
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
    our $HAVE_INFORMIX = 1;

    #Rose::DB::Object::Metadata->unregister_all_classes;

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

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL NOT NULL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),
  
  UNIQUE(name, vendor_id),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL NOT NULL PRIMARY KEY,
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
    our $HAVE_SQLITE = 1;

    #Rose::DB::Object::Metadata->unregister_all_classes;

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

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  code  CHAR(3) NOT NULL PRIMARY KEY,
  name  VARCHAR(255),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id        SERIAL NOT NULL PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),
  
  UNIQUE(name, vendor_id),
  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           SERIAL NOT NULL PRIMARY KEY,
  product_id   INT NOT NULL REFERENCES products (id),
  color_code   CHAR(3) NOT NULL REFERENCES colors (code)
)
EOF

    $dbh->disconnect;
  }
}

sub slurp
{
  my($path) = shift;

  return undef  unless(-e $path);

  open(my $fh, $path) or die "Could not open '$path' - $!";
  my $data = do { local $/; <$fh> };

  return $data;
}

END
{
  eval 'require File::Path';

  # Delete the lib dir  
  unless($@)
  {
    #File::Path::rmtree($Lib_Dir, 0, 1);
  }
  
  # Delete test tables

  if($HAVE_PG)
  {
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL_WITH_INNODB)
  {
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if($HAVE_SQLITE)
  {
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
