#!/usr/bin/perl -w

use strict;

use Test::More tests => 2 + (5 * 6);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::Loader');
  use_ok('Rose::DB::Object::Helpers');
}

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

our %Have;

#
# Tests
#

use Rose::DB::Object::Constants qw(STATE_SAVING);

#$Rose::DB::Object::Manager::Debug = 1;

if(defined $ENV{'RDBO_NESTED_JOINS'} && Rose::DB::Object::Manager->can('default_nested_joins'))
{
  Rose::DB::Object::Manager->default_nested_joins($ENV{'RDBO_NESTED_JOINS'});
}

my $Include = 
  '^(?:' . join('|', qw(colors descriptions authors nicknames
                        description_author_map product_color_map
                        prices products vendors regions)) . ')$';
$Include = qr($Include);

foreach my $db_type (qw(sqlite mysql pg pg_with_schema informix))
{
  SKIP:
  {
    skip("$db_type tests", 6)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  Rose::DB::Object::Metadata->unregister_all_classes;

  # Test of the subselect limit code
  #Rose::DB::Object::Manager->default_limit_with_subselect(1)  if($db_type =~ /^pg/);

  my $db = Rose::DB->new;

  my $class_prefix = 
    ucfirst($db_type eq 'pg_with_schema' ? 'pgws' : $db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
      db           => $db,
      class_prefix => $class_prefix);

  my @classes = $loader->make_classes(include_tables => $Include);

  foreach my $class (@classes)
  {
    next  unless($class->isa('Rose::DB::Object'));

    if(my @rels = grep { !$_->is_singular } $class->meta->relationships)
    {
      foreach my $rel (@rels)
      {
        if($rel->type eq 'many to many')
        {
          $rel->manager_args({ sort_by => 't2.id' });
        }
        else
        {
          $rel->manager_args({ sort_by => 'id' });
        }
      }

      $class->meta->make_relationship_methods(replace_existing => 1);
    }
  }

  my $product_class = $class_prefix  . '::Product';
  my $manager_class = $product_class . '::Manager';

  Rose::DB::Object::Helpers->import(-target_class => $product_class, qw(as_tree new_from_tree init_with_tree));

  my $p1 = 
    $product_class->new(
      id     => 1,
      name   => 'Kite',
      vendor => { id => 1, name => 'V1', region => { id => 'DE', name => 'Germany' } },
      prices => 
      [
        { price => 1.23, region => { id => 'US', name => 'America' } }, 
        { price => 4.56, region => { id => 'DE', name => 'Germany' } },
      ],
      colors => 
      [
        {
          name => 'red',
          description => 
          {
            text => 'desc 1',
            authors => 
            [
              {
                name => 'john',
                nicknames => [ { nick => 'jack' }, { nick => 'sir' } ],
              },
              {
                name => 'sue',
                nicknames => [ { nick => 'sioux' } ],
              },
            ],
          },
        }, 
        {
          name => 'blue',
          description => 
          {
            text => 'desc 2',
            authors => 
            [
              { name => 'john' },
              {
                name => 'jane',
                nicknames => [ { nick => 'blub' } ],
              },
            ],
          }
        }
      ]);

  $p1->save;

  my $p2 = 
    $product_class->new(
      id     => 2,
      name   => 'Sled',
      vendor => { id => 2, name => 'V2', region_id => 'US', vendor_id => 1 },
      prices => [ { price => 9.99 } ],
      colors => 
      [
        { name => 'red' }, 
        {
          name => 'green',
          description => 
          {
            text => 'desc 3',
            authors => [ { name => 'tim' } ],
          }
        }
      ]);

  $p2->save;

  my $tree      = $p2->as_tree;
  my $from_tree = $product_class->new_from_tree($tree);

  is_deeply($tree, $from_tree->as_tree, "as_tree -> new_from_tree -> as_tree 1 - $db_type");
  is_deeply($tree, $from_tree->as_tree, "as_tree -> new_from_tree -> as_tree 2 - $db_type");

  #require YAML::Syck;
  #print YAML::Syck::Dump($tree);
  #
  #print Dumper($tree);
  #print "########################\n";
  #$DB::single = 1;
  #print Dumper($from_tree->as_tree);
  #print YAML::Syck::Dump($from_tree->as_tree);
  #exit;

  $tree = $product_class->new(id => 2)->as_tree(force_load => 1, max_depth => 0);

  my $check_tree = 
  {
    'colors' => 
    [
      {
        'description_id' => '1',
        'id' => '1',
        'name' => 'red'
      },
      {
        'description_id' => '3',
        'id' => '3',
        'name' => 'green'
      }
    ],
    'id' => '2',
    'name' => 'Sled',
    'prices' =>
    [
      {
        'id' => '3',
        'price' => '9.99',
        'product_id' => '2',
        'region_id' => 'US'
      }
    ],
    'vendor' =>
    {
      'id' => '2',
      'name' => 'V2',
      'region_id' => 'US',
      'vendor_id' => '1'
    },
    'vendor_id' => '2'
  };

  is_deeply($tree, $check_tree, "as_tree force_load => 1, max_depth => 0 - $db_type");

  $tree = $product_class->new(id => 2)->as_tree(force_load => 1, max_depth => 1);

  $check_tree =
  {
    'colors' => 
    [
      {
        'description' => 
        {
          'id'   => '1',
          'text' => 'desc 1'
        },
        'description_id' => '1',
        'id'             => '1',
        'name'           => 'red',
        'products'       => 
        [
          {
            'id'        => '1',
            'name'      => 'Kite',
            'vendor_id' => '1'
          }
        ]
      },
      {
        'description' => 
        {
          'id'   => '3',
          'text' => 'desc 3'
        },
        'description_id' => '3',
        'id'             => '3',
        'name'           => 'green',
        'products'       => []
      }
    ],
    'id'     => '2',
    'name'   => 'Sled',
    'prices' => 
    [
      {
        'id'         => '3',
        'price'      => '9.99',
        'product'    => {},
        'product_id' => '2',
        'region'     => 
        {
          'id'   => 'US',
          'name' => 'America'
        },
        'region_id' => 'US'
      }
    ],
    'vendor' => 
    {
      'id'        => '2',
      'name'      => 'V2',
      'products'  => [],
      'region'    => {},
      'region_id' => 'US',
      'vendor'    => 
      {
        'id'        => '1',
        'name'      => 'V1',
        'region_id' => 'DE',
        'vendor_id' => undef
      },
      'vendor_id' => '1',
      'vendors'   => []
    },
    'vendor_id' => '2'
  };

  is_deeply($tree, $check_tree, "as_tree force_load => 1, max_depth => 1 - $db_type");

  $tree = $product_class->new(id => 2)->as_tree(force_load => 1, max_depth => 1, allow_loops => 1);

  $check_tree =
  {
    'colors' => 
    [
      {
        'description' => 
        {
          'id'   => '1',
          'text' => 'desc 1'
        },
        'description_id' => '1',
        'id'             => '1',
        'name'           => 'red',
        'products'       => 
        [
          {
            'id'        => '1',
            'name'      => 'Kite',
            'vendor_id' => '1'
          },
          {
            'id'        => '2',
            'name'      => 'Sled',
            'vendor_id' => '2'
          }
        ]
      },
      {
        'description' => 
        {
          'id'   => '3',
          'text' => 'desc 3'
        },
        'description_id' => '3',
        'id'             => '3',
        'name'           => 'green',
        'products'       => 
        [
          {
            'id'        => '2',
            'name'      => 'Sled',
            'vendor_id' => '2'
          }
        ]
      }
    ],
    'id'     => '2',
    'name'   => 'Sled',
    'prices' => 
    [
      {
        'id'      => '3',
        'price'   => '9.99',
        'product' => 
        {
          'id'        => '2',
          'name'      => 'Sled',
          'vendor_id' => '2'
        },
        'product_id' => '2',
        'region'     => 
        {
          'id'   => 'US',
          'name' => 'America'
        },
        'region_id' => 'US'
      }
    ],
    'vendor' => 
    {
      'id'       => '2',
      'name'     => 'V2',
      'products' => 
      [
        {
          'id'        => '2',
          'name'      => 'Sled',
          'vendor_id' => '2'
        }
      ],
      'region' => 
      {
        'id'   => 'US',
        'name' => 'America'
      },
      'region_id' => 'US',
      'vendor'    => 
      {
        'id'        => '1',
        'name'      => 'V1',
        'region_id' => 'DE',
        'vendor_id' => undef
      },
      'vendor_id' => '1',
      'vendors'   => []
    },
    'vendor_id' => '2'
  };

  is_deeply($tree, $check_tree, "as_tree force_load => 1, max_depth => 1, allow_loops => 1 - $db_type");
#$Rose::DB::Object::Manager::Debug = 1;
  $tree = $product_class->new(id => 2)->as_tree(force_load => 1, max_depth => 2);
#$Rose::DB::Object::Manager::Debug = 0;
  $check_tree =
  {
    'colors' => 
    [
      {
        'description' => 
        {
          'authors' => 
          [
            {
              'id'   => '1',
              'name' => 'john'
            },
            {
              'id'   => '2',
              'name' => 'sue'
            }
          ],
          'colors' => [],
          'id'     => '1',
          'text'   => 'desc 1'
        },
        'description_id' => '1',
        'id'             => '1',
        'name'           => 'red',
        'products'       => 
        [
          {
            'colors' => 
            [
              {
                'description_id' => '2',
                'id'             => '2',
                'name'           => 'blue'
              }
            ],
            'id'     => '1',
            'name'   => 'Kite',
            'prices' => 
            [
              {
                'id'         => '1',
                'price'      => '1.23',
                'product_id' => '1',
                'region_id'  => 'US'
              },
              {
                'id'         => '2',
                'price'      => '4.56',
                'product_id' => '1',
                'region_id'  => 'DE'
              }
            ],
            'vendor' => 
            {
              'id'        => '1',
              'name'      => 'V1',
              'region_id' => 'DE',
              'vendor_id' => undef
            },
            'vendor_id' => '1'
          }
        ]
      },
      {
        'description' => 
        {
          'authors' => 
          [
            {
              'id'   => '4',
              'name' => 'tim'
            }
          ],
          'colors' => [],
          'id'     => '3',
          'text'   => 'desc 3'
        },
        'description_id' => '3',
        'id'             => '3',
        'name'           => 'green',
        'products'       => []
      }
    ],
    'id'     => '2',
    'name'   => 'Sled',
    'prices' => 
    [
      {
        'id'         => '3',
        'price'      => '9.99',
        'product'    => {},
        'product_id' => '2',
        'region'     => 
        {
          'id'      => 'US',
          'name'    => 'America',
          'prices'  => [],
          'vendors' => 
          [
            {
              'id'        => '2',
              'name'      => 'V2',
              'region_id' => 'US',
              'vendor_id' => '1'
            }
          ]
        },
        'region_id' => 'US'
      }
    ],
    'vendor'    => {},
    'vendor_id' => '2'
  };

  is_deeply($tree, $check_tree, "as_tree force_load => 1, max_depth => 2 - $db_type");
  #is(Dumper($tree), Dumper($check_tree), "as_tree force_load => 1, max_depth => 2 - $db_type");

#print Dumper($tree);
#$DB::single = 1;
#exit;

  my $p3 = 
    $product_class->new(
      id     => 3,
      name   => 'Barn',
      vendor => { id => 3, name => 'V3', region => { id => 'UK', name => 'England' }, vendor_id => 2 },
      prices => [ { price => 100 } ],
      colors => 
      [
        { name => 'green' }, 
        {
          name => 'pink',
          description => 
          {
            text => 'desc 4',
            authors => [ { name => 'joe', nicknames => [ { nick => 'joey' } ] } ],
          }
        }
      ]);

  $p3->save;

  #local $Rose::DB::Object::Manager::Debug = 1;
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

    #die "This test chokes DBD::Pg version 2.1.x and 2.2.0"  if($DBD::Pg::VERSION =~ /^2\.(?:1\.|2\.0)/);
  };

  if(!$@ && $dbh)
  {
    $Have{'pg'} = 1;
    $Have{'pg_with_schema'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE product_color_map CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE description_author_map CASCADE');
      $dbh->do('DROP TABLE nicknames CASCADE');
      $dbh->do('DROP TABLE authors CASCADE');
      $dbh->do('DROP TABLE descriptions CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
      $dbh->do('DROP TABLE regions CASCADE');

      $dbh->do('DROP TABLE Rose_db_object_private.product_color_map CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.colors CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.description_author_map CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.nicknames CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.authors CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.descriptions CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.prices CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.products CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.vendors CASCADE');
      $dbh->do('DROP TABLE Rose_db_object_private.regions CASCADE');

      $dbh->do('CREATE SCHEMA Rose_db_object_private');
    }

    $dbh->do(<<"EOF");
CREATE TABLE regions
(
  id    CHAR(2) NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  vendor_id INT REFERENCES vendors (id),
  region_id CHAR(2) REFERENCES regions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,

  vendor_id  INT REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region_id   CHAR(2) NOT NULL REFERENCES regions (id) DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE descriptions
(
  id    SERIAL NOT NULL PRIMARY KEY,
  text  VARCHAR(255) NOT NULL,

  UNIQUE(text)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE authors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE nicknames
(
  id         SERIAL NOT NULL PRIMARY KEY,
  nick       VARCHAR(255) NOT NULL,
  author_id  INT REFERENCES authors (id),

  UNIQUE(nick, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE description_author_map
(
  description_id  INT NOT NULL REFERENCES descriptions (id),
  author_id       INT NOT NULL REFERENCES authors (id),

  PRIMARY KEY(description_id, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  description_id INT REFERENCES descriptions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_color_map
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.regions
(
  id    CHAR(2) NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  vendor_id INT REFERENCES Rose_db_object_private.vendors (id),
  region_id CHAR(2) REFERENCES Rose_db_object_private.regions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,

  vendor_id  INT REFERENCES Rose_db_object_private.vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES Rose_db_object_private.products (id),
  region_id   CHAR(2) NOT NULL REFERENCES Rose_db_object_private.regions (id) DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.descriptions
(
  id    SERIAL NOT NULL PRIMARY KEY,
  text  VARCHAR(255) NOT NULL,

  UNIQUE(text)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.authors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.nicknames
(
  id         SERIAL NOT NULL PRIMARY KEY,
  nick       VARCHAR(255) NOT NULL,
  author_id  INT REFERENCES Rose_db_object_private.authors (id),

  UNIQUE(nick, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.description_author_map
(
  description_id  INT NOT NULL REFERENCES Rose_db_object_private.descriptions (id),
  author_id       INT NOT NULL REFERENCES Rose_db_object_private.authors (id),

  PRIMARY KEY(description_id, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.colors
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  description_id INT REFERENCES Rose_db_object_private.descriptions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.product_color_map
(
  product_id  INT NOT NULL REFERENCES Rose_db_object_private.products (id),
  color_id    INT NOT NULL REFERENCES Rose_db_object_private.colors (id),

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

    die "MySQL version too old"  unless($db->database_version >= 4_000_000);

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE product_color_map CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE descriptions CASCADE');
      $dbh->do('DROP TABLE authors CASCADE');
      $dbh->do('DROP TABLE nicknames CASCADE');
      $dbh->do('DROP TABLE description_author_map CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
      $dbh->do('DROP TABLE regions CASCADE');
    }

    $dbh->do(<<"EOF");
CREATE TABLE regions
(
  id    CHAR(2) NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    # MySQL will silently ignore the "TYPE=InnoDB" part and create
    # a MyISAM table instead.  MySQL is evil!  Now we have to manually
    # check to make sure an InnoDB table was really created.
    my $db_name = $db->database;
    my $sth = $dbh->prepare("SHOW TABLE STATUS FROM `$db_name` LIKE ?");
    $sth->execute('regions');
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
CREATE TABLE vendors
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  vendor_id INT,
  region_id CHAR(2),

  INDEX(vendor_id),
  INDEX(region_id),

  FOREIGN KEY (vendor_id) REFERENCES vendors (id),
  FOREIGN KEY (region_id) REFERENCES regions (id),

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,

  vendor_id  INT,

  INDEX(vendor_id),

  FOREIGN KEY (vendor_id) REFERENCES vendors (id),

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT,
  region_id   CHAR(2) NOT NULL DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  INDEX(product_id),
  INDEX(region_id),

  FOREIGN KEY (product_id) REFERENCES products (id),
  FOREIGN KEY (region_id) REFERENCES regions (id),

  UNIQUE(product_id, region_id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE descriptions
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  text  VARCHAR(255) NOT NULL,

  UNIQUE(text)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE authors
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE nicknames
(
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nick       VARCHAR(255) NOT NULL,
  author_id  INT,

  INDEX(author_id),

  FOREIGN KEY (author_id) REFERENCES authors (id),

  UNIQUE(nick, author_id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE description_author_map
(
  description_id  INT NOT NULL,
  author_id       INT NOT NULL,

  INDEX(description_id),
  INDEX(author_id),

  FOREIGN KEY (description_id) REFERENCES descriptions (id),
  FOREIGN KEY (author_id) REFERENCES authors (id),

  PRIMARY KEY(description_id, author_id)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id      INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  description_id INT,

  INDEX(description_id),

  FOREIGN KEY (description_id) REFERENCES descriptions (id),

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_color_map
(
  product_id  INT NOT NULL,
  color_id    INT NOT NULL,

  INDEX(product_id),
  INDEX(color_id),

  FOREIGN KEY (product_id) REFERENCES products (id),
  FOREIGN KEY (color_id) REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
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

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE product_color_map CASCADE');
      $dbh->do('DROP TABLE colors CASCADE');
      $dbh->do('DROP TABLE description_author_map CASCADE');
      $dbh->do('DROP TABLE nicknames CASCADE');
      $dbh->do('DROP TABLE authors CASCADE');
      $dbh->do('DROP TABLE descriptions CASCADE');
      $dbh->do('DROP TABLE prices CASCADE');
      $dbh->do('DROP TABLE products CASCADE');
      $dbh->do('DROP TABLE vendors CASCADE');
      $dbh->do('DROP TABLE regions CASCADE');
    }

    $dbh->do(<<"EOF");
CREATE TABLE regions
(
  id    CHAR(2) NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  vendor_id INT REFERENCES vendors (id),
  region_id CHAR(2) REFERENCES regions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,

  vendor_id  INT REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          SERIAL NOT NULL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES products (id),
  region_id   CHAR(2) DEFAULT 'US' NOT NULL REFERENCES regions (id),
  price       DECIMAL(10,2) DEFAULT 0.00 NOT NULL,

  UNIQUE(product_id, region_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE descriptions
(
  id    SERIAL NOT NULL PRIMARY KEY,
  text  VARCHAR(255) NOT NULL,

  UNIQUE(text)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE authors
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE nicknames
(
  id         SERIAL NOT NULL PRIMARY KEY,
  nick       VARCHAR(255) NOT NULL,
  author_id  INT REFERENCES authors (id),

  UNIQUE(nick, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE description_author_map
(
  description_id  INT NOT NULL REFERENCES descriptions (id),
  author_id       INT NOT NULL REFERENCES authors (id),

  PRIMARY KEY(description_id, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id      SERIAL NOT NULL PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  description_id INT REFERENCES descriptions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_color_map
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
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

      $dbh->do('DROP TABLE colors');
      $dbh->do('DROP TABLE descriptions');
      $dbh->do('DROP TABLE authors');
      $dbh->do('DROP TABLE nicknames');
      $dbh->do('DROP TABLE description_author_map');
      $dbh->do('DROP TABLE product_color_map');
      $dbh->do('DROP TABLE prices');
      $dbh->do('DROP TABLE products');
      $dbh->do('DROP TABLE vendors');
      $dbh->do('DROP TABLE regions');
    }

    $dbh->do(<<"EOF");
CREATE TABLE regions
(
  id    CHAR(2) NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE vendors
(
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  VARCHAR(255) NOT NULL,

  vendor_id INT REFERENCES vendors (id),
  region_id CHAR(2) REFERENCES regions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE products
(
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  name    VARCHAR(255) NOT NULL,

  vendor_id  INT REFERENCES vendors (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE prices
(
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id  INT NOT NULL REFERENCES products (id),
  region_id   CHAR(2) NOT NULL REFERENCES regions (id) DEFAULT 'US',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  UNIQUE(product_id, region_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE descriptions
(
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  text  VARCHAR(255) NOT NULL,

  UNIQUE(text)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE authors
(
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE nicknames
(
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  nick       VARCHAR(255) NOT NULL,
  author_id  INT REFERENCES authors (id),

  UNIQUE(nick, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE description_author_map
(
  description_id  INT NOT NULL REFERENCES descriptions (id),
  author_id       INT NOT NULL REFERENCES authors (id),

  PRIMARY KEY(description_id, author_id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE colors
(
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  name    VARCHAR(255) NOT NULL,
  description_id INT REFERENCES descriptions (id),

  UNIQUE(name)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE product_color_map
(
  product_id  INT NOT NULL REFERENCES products (id),
  color_id    INT NOT NULL REFERENCES colors (id),

  PRIMARY KEY(product_id, color_id)
)
EOF

    $dbh->disconnect;
  }
}

END
{
  if($Have{'pg'})
  {
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_color_map CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE description_author_map CASCADE');
    $dbh->do('DROP TABLE nicknames CASCADE');
    $dbh->do('DROP TABLE authors CASCADE');
    $dbh->do('DROP TABLE descriptions CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');
    $dbh->do('DROP TABLE regions CASCADE');

    $dbh->do('DROP TABLE Rose_db_object_private.product_color_map CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.colors CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.description_author_map CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.nicknames CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.authors CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.descriptions CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.prices CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.products CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.vendors CASCADE');
    $dbh->do('DROP TABLE Rose_db_object_private.regions CASCADE');

    $dbh->do('DROP SCHEMA Rose_db_object_private CASCADE');

    $dbh->disconnect;
  }

  if($Have{'mysql'})
  {
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_color_map CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE description_author_map CASCADE');
    $dbh->do('DROP TABLE nicknames CASCADE');
    $dbh->do('DROP TABLE authors CASCADE');
    $dbh->do('DROP TABLE descriptions CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');
    $dbh->do('DROP TABLE regions CASCADE');

    $dbh->disconnect;
  }

  if($Have{'informix'})
  {
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE product_color_map CASCADE');
    $dbh->do('DROP TABLE colors CASCADE');
    $dbh->do('DROP TABLE description_author_map CASCADE');
    $dbh->do('DROP TABLE nicknames CASCADE');
    $dbh->do('DROP TABLE authors CASCADE');
    $dbh->do('DROP TABLE descriptions CASCADE');
    $dbh->do('DROP TABLE prices CASCADE');
    $dbh->do('DROP TABLE products CASCADE');
    $dbh->do('DROP TABLE vendors CASCADE');
    $dbh->do('DROP TABLE regions CASCADE');

    $dbh->disconnect;
  }

  if($Have{'sqlite'})
  {
    my $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE colors');
    $dbh->do('DROP TABLE descriptions');
    $dbh->do('DROP TABLE authors');
    $dbh->do('DROP TABLE nicknames');
    $dbh->do('DROP TABLE description_author_map');
    $dbh->do('DROP TABLE product_color_map');
    $dbh->do('DROP TABLE prices');
    $dbh->do('DROP TABLE products');
    $dbh->do('DROP TABLE vendors');
    $dbh->do('DROP TABLE regions');

    $dbh->disconnect;
  }
}

sub has_broken_order_by
{
  my($db_type) = shift;

  if($db_type eq 'sqlite' && $DBD::SQLite::VERSION < 1.11)
  {
    return 1;
  }

  return 0;
}

sub cmp_sql
{
  my($a, $b, $msg) = @_;

  for($a, $b)
  {
    s/\s+/ /g;
    s/^\s+//;
    s/\s+$//;
    s/^SELECT.*?FROM/SELECT * FROM/;
    s/\brose_db_object_private\.//g;
  }

  @_ = ($a, $b, $msg);

  goto &is;
}
