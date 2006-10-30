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
  Test::More->import(tests => 2 + (3 * 4));
}
else
{
  Test::More->import(skip_all => "Could not mkdir($Lib_Dir) - $!");
}

require 't/test-lib.pl';
use_ok('Rose::DB::Object');
use_ok('Rose::DB::Object::Loader');

my $Include_Tables = '^(?:' . join('|', 
  qw(product_colors prices products colors vendors)) . ')$';
$Include_Tables = qr($Include_Tables);

my %Column_Defs =
(
  pg => 
  {
    id        => q(id        => { type => 'serial', not_null => 1 },),
    vendor_id => q(vendor_id => { type => 'integer', not_null => 1 },),
  },

  mysql => 
  {
    id        => q(id        => { type => 'integer', not_null => 1 },),
    vendor_id => q(vendor_id => { type => 'integer', default => '', not_null => 1 },),
  },

  sqlite => 
  {
    id        => q(id        => { type => 'integer' },),
    vendor_id => q(vendor_id => { type => 'integer', not_null => 1 },),
  },

  informix => 
  {
    id        => q(id        => { type => 'serial', not_null => 1 },),
    vendor_id => q(vendor_id => { type => 'integer', not_null => 1 },),
  },
);

use Config;

my $Perl = $^X;

if($^O ne 'VMS')
{
  $Perl .= $Config{'_exe'}  unless($Perl =~ /$Config{'_exe'}$/i);
}

#
# Tests
#

foreach my $db_type (qw(pg mysql informix sqlite))
{
  unless(have_db($db_type))
  {
    SKIP: { skip("$db_type tests", 3) }
    next;
  }

  Rose::DB::Object::Metadata->unregister_all_classes;

  Rose::DB->default_type($db_type);

  my $class_prefix = 'My' . ucfirst($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
    db_class       => 'Rose::DB',
    class_prefix   => $class_prefix,
    include_tables => $Include_Tables);

  $loader->make_modules(module_dir   => $Lib_Dir,
                        braces       => 'bsd',
                        indent       => 2);

  is(slurp("$Lib_Dir/$class_prefix/Product.pm"), <<"EOF", "Product 1 - $db_type");
package ${class_prefix}::Product;

use strict;

use base qw(${class_prefix}::DB::Object::AutoBaseNNN);

__PACKAGE__->meta->setup
(
  table   => 'products',

  columns => 
  [
    $Column_Defs{$db_type}{'id'}
    name      => { type => 'varchar', length => 255 },
    $Column_Defs{$db_type}{'vendor_id'}
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
      class       => '${class_prefix}::Vendor',
      key_columns => { vendor_id => 'id' },
    },
  ],

  relationships => 
  [
    colors => 
    {
      column_map    => { product_id => 'id' },
      foreign_class => '${class_prefix}::Color',
      map_class     => '${class_prefix}::ProductColor',
      map_from      => 'product',
      map_to        => 'color',
      type          => 'many to many',
    },

    prices => 
    {
      class      => '${class_prefix}::Price',
      column_map => { id => 'product_id' },
      type       => 'one to many',
    },
  ],
);

1;

EOF

  is(slurp("$Lib_Dir/$class_prefix/Color.pm"), <<"EOF", "Color 1 - $db_type");
package ${class_prefix}::Color;

use strict;

use base qw(${class_prefix}::DB::Object::AutoBaseNNN);

__PACKAGE__->meta->setup
(
  table   => 'colors',

  columns => 
  [
    code => { type => 'character', length => 3, not_null => 1 },
    name => { type => 'varchar', length => 255 },
  ],

  primary_key_columns => [ 'code' ],

  unique_key => [ 'name' ],

  relationships => 
  [
    products => 
    {
      column_map    => { color_code => 'code' },
      foreign_class => '${class_prefix}::Product',
      map_class     => '${class_prefix}::ProductColor',
      map_from      => 'color',
      map_to        => 'product',
      type          => 'many to many',
    },
  ],
);

1;

EOF

  unshift(@INC, $Lib_Dir);

  # Test actual code by running external script with db type arg

  my($ok, $script_fh);

  # Perl 5.8.x and later support the FILEHANDLE,MODE,EXPR,LIST form of 
  # open, but not (apparently) on Windows
  if($Config{'version'} =~ /^5\.([89]|10)\./ && $^O !~ /Win32/i)
  {
    $ok = open($script_fh, '-|', $Perl, 't/make-modules.ext', $db_type);
  }
  else
  {
    $ok = open($script_fh, "$Perl t/make-modules.ext $db_type |");
  }

  if($ok)
  {
    chomp(my $line = <$script_fh>);
    close($script_fh);
    is($line, 'V1; IS: 1.23, DE: 4.56; red, green; red: CC1', "external test - $db_type");
  }
  else
  {
    ok(0, "Failed to open external script for $db_type - $!");
  }

  shift(@INC);
}

BEGIN
{
  require 't/test-lib.pl';

  #
  # Postgres
  #

  if(have_db('pg_admin'))
  {
    my $dbh = get_dbh('pg_admin');

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

  eval
  {
    my $db = get_db('mysql_admin');
    my $dbh = $db->retain_dbh or die Rose::DB->error;
    my $db_version = $db->database_version;

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
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255)
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

  if($@)
  {
    have_db(mysql_admin => 0);
    have_db(mysql => 0);
  }

  if(have_db('mysql_admin'))
  {
    my $dbh = get_dbh('mysql_admin');

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
  id        INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(255),
  vendor_id INT NOT NULL,

  UNIQUE(name, vendor_id),
  UNIQUE(name),

  INDEX(vendor_id),

  FOREIGN KEY (vendor_id) REFERENCES vendors (id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  price_id    INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL,
  region      CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL,

  INDEX(product_id),

  FOREIGN KEY (product_id) REFERENCES products (id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_colors
(
  id           INT AUTO_INCREMENT PRIMARY KEY,
  product_id   INT NOT NULL,
  color_code   CHAR(3) NOT NULL,

  INDEX(product_id),
  INDEX(color_code),

  FOREIGN KEY (product_id) REFERENCES products (id),
  FOREIGN KEY (color_code) REFERENCES colors (code)
)
TYPE=InnoDB
EOF

    $dbh->disconnect;
  }

  #
  # Informix
  #

  if(have_db('informix_admin'))
  {
    my $dbh = get_dbh('informix_admin');

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
  region      CHAR(2) DEFAULT 'US' NOT NULL,
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

  if(have_db('sqlite_admin'))
  {
    my $dbh = get_dbh('sqlite_admin');

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
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
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
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      VARCHAR(255),
  vendor_id INT NOT NULL REFERENCES vendors (id),

  UNIQUE(name, vendor_id),
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

sub slurp
{
  my($path) = shift;

  return undef  unless(-e $path);

  open(my $fh, $path) or die "Could not open '$path' - $!";
  my $data = do { local $/; <$fh> };

  # Normalize auto-numbered base classes
  for($data)
  {
    s/::DB::Object::AutoBase\d+/::DB::Object::AutoBaseNNN/g;
    # MySQL 4.1.2 apparently defaults INTEGER NOT NULL columns to 0
    s/default => '0',/default => '',/;
  }

  return $data;
}

END
{
  eval 'require File::Path';

  # Delete the lib dir  
  unless($@)
  {
    File::Path::rmtree($Lib_Dir, 0, 1);
  }

  # Delete test tables

  if(have_db('pg_admin'))
  {
    my $dbh = get_dbh('pg_admin');

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if(have_db('mysql_admin'))
  {
    my $dbh = get_dbh('mysql_admin');

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if(have_db('informix_admin'))
  {
    my $dbh = get_dbh('informix_admin');

    $dbh->do('DROP TABLE product_colors CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');

    $dbh->disconnect;
  }

  if(have_db('sqlite_admin'))
  {
    my $dbh = get_dbh('sqlite_admin');

    $dbh->do('DROP TABLE product_colors');
    $dbh->do('DROP TABLE prices');
    $dbh->do('DROP TABLE products');
    $dbh->do('DROP TABLE colors');
    $dbh->do('DROP TABLE vendors');

    $dbh->disconnect;
  }
}
