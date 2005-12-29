#!/usr/bin/perl -w

use strict;

use Test::More tests => 1496;

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

my $Include = 
  '^(?:' . join('|', qw(colors descriptions authors nicknames
                        description_author_map product_color_map
                        prices products vendors regions)) . ')$';
$Include = qr($Include);
  
foreach my $db_type (qw(sqlite mysql pg pg_with_schema informix))
{
  SKIP:
  {
    skip("$db_type tests", 299)  unless($Have{$db_type});
  }
  
  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  Rose::DB::Object::Metadata->unregister_all_classes;

  my $class_prefix = 
    ucfirst($db_type eq 'pg_with_schema' ? 'pgws' : $db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
      db           => Rose::DB->new,
      class_prefix => $class_prefix);

  my @classes = $loader->make_classes(include_tables => $Include);

  my $product_class = $class_prefix  . '::Product';
  my $manager_class = $product_class . '::Manager';

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

  my $products = 
    $manager_class->get_products(
      require_objects => [ 'vendor.vendor', 'vendor.region' ]);

  is(scalar @$products, 2, "require vendors 1 - $db_type");

  is($products->[0]{'vendor'}{'id'}, 2, "p2 - require vendors 1 - $db_type");
  is($products->[0]{'vendor'}{'vendor'}{'id'}, 1, "p2 - require vendors 2 - $db_type");
  is($products->[0]{'vendor'}{'region'}{'name'}, 'America', "p2 - require vendors 3 - $db_type");
  
  is($products->[1]{'vendor'}{'id'}, 3, "p3 - require vendors 1 - $db_type");
  is($products->[1]{'vendor'}{'vendor'}{'id'}, 2, "p3 - require vendors 2 - $db_type");
  is($products->[1]{'vendor'}{'region'}{'name'}, 'England', "p3 - require vendors 3 - $db_type");

  $products = 
    $manager_class->get_products(
      require_objects => [ 'vendor.vendor', 'vendor.region' ],
      limit  => 10,
      offset => 1);

  is(scalar @$products, 1, "offset require vendors 1 - $db_type");
  
  is($products->[0]{'vendor'}{'id'}, 3, "p3 - offset require vendors 1 - $db_type");
  is($products->[0]{'vendor'}{'vendor'}{'id'}, 2, "p3 - offset require vendors 2 - $db_type");
  is($products->[0]{'vendor'}{'region'}{'name'}, 'England', "p3 - offset require vendors 3 - $db_type");

  my $iterator = 
    $manager_class->get_products_iterator(
      require_objects => [ 'vendor.vendor', 'vendor.region' ]);

  my $p = $iterator->next;
  is($p->{'vendor'}{'id'}, 2, "p2 - require vendors iterator 1 - $db_type");
  is($p->{'vendor'}{'vendor'}{'id'}, 1, "p2 - require vendors iterator 2 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'America', "p2 - require vendors iterator 3 - $db_type");
  
  $p = $iterator->next;
  is($p->{'vendor'}{'id'}, 3, "p3 - require vendors iterator 1 - $db_type");
  is($p->{'vendor'}{'vendor'}{'id'}, 2, "p3 - require vendors iterator 2 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'England', "p3 - require vendors iterator 3 - $db_type");

  ok(!$iterator->next, "require vendors iterator 1 - $db_type");
  is($iterator->total, 2, "require vendors iterator 2 - $db_type");

  $iterator = 
    $manager_class->get_products_iterator(
      require_objects => [ 'vendor.vendor', 'vendor.region' ],
      limit  => 10,
      offset => 1);

  $p = $iterator->next;
  is($p->{'vendor'}{'id'}, 3, "p3 - offset require vendors iterator 1 - $db_type");
  is($p->{'vendor'}{'vendor'}{'id'}, 2, "p3 - offset require vendors iterator 2 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'England', "p3 - offset require vendors iterator 3 - $db_type");

  ok(!$iterator->next, "offset require vendors iterator 1 - $db_type");
  is($iterator->total, 1, "offset require vendors iterator 2 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $products = 
    $manager_class->get_products(
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 2,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  is($products->[0]{'colors'}[0]{'name'}, 'red', "p1 - with colors 1 - $db_type");
  is($products->[0]{'colors'}[1]{'name'}, 'blue', "p1 - with colors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}}, 2, "p1 - with colors 3  - $db_type");
  
  is($products->[0]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p1 - with colors description 1 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'text'}, 'desc 2', "p1 - with colors description 2 - $db_type");

  #$products->[0]{'colors'}[0]{'description'}{'authors'} = 
  #  [ sort { $a->{'name'} cmp $b->{'name'} } @{$products->[0]{'colors'}[0]{'description'}{'authors'}} ];

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p1 - with colors description authors 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p1 - with colors description authors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}}, 2, "p1 - with colors description authors 3  - $db_type");

  #$products->[0]{'colors'}[1]{'description'}{'authors'} = 
  #  [ sort { $a->{'name'} cmp $b->{'name'} } @{$products->[0]{'colors'}[1]{'description'}{'authors'}} ];

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'jane', "p1 - with colors description authors 4 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'name'}, 'john', "p1 - with colors description authors 5 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}}, 2, "p1 - with colors description authors 6  - $db_type");

  $products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p1 - with colors description authors nicknames 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p1 - with colors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p1 - with colors description authors nicknames 3 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p1 - with colors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p1 - with colors description authors nicknames 5 - $db_type");

  $products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}} ];

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'jack', "p1 - with colors description authors nicknames 6 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[1]{'nick'}, 'sir', "p1 - with colors description authors nicknames 7 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}}, 2, "p1 - with colors description authors nicknames 8 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'blub', "p1 - with colors description authors nicknames 9 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}}, 1, "p1 - with colors description authors nicknames 10  - $db_type");

  is($products->[1]{'colors'}[0]{'name'}, 'red', "p2 - with colors 1 - $db_type");
  is($products->[1]{'colors'}[1]{'name'}, 'green', "p2 - with colors 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}}, 2, "p2 - with colors 3  - $db_type");
  
  is($products->[1]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - with colors description 1 - $db_type");
  is($products->[1]{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - with colors description 2 - $db_type");

  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - with colors description authors 1 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - with colors description authors 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - with colors description authors 3  - $db_type");

  is($products->[1]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - with colors description authors 4 - $db_type");
  is(scalar @{$products->[1]{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - with colors description authors 6  - $db_type");

  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - with colors description authors nicknames 1 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - with colors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - with colors description authors nicknames 3 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - with colors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - with colors description authors nicknames 5 - $db_type");

  is(scalar @{$products->[1]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - with colors description authors nicknames 6 - $db_type");

  $products = 
    $manager_class->get_products(
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 1,
      offset          => 1,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  is($products->[0]{'colors'}[0]{'name'}, 'red', "p2 - offset with colors 1 - $db_type");
  is($products->[0]{'colors'}[1]{'name'}, 'green', "p2 - offset with colors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}}, 2, "p2 - offset with colors 3  - $db_type");
  
  is($products->[0]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - offset with colors description 1 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - offset with colors description 2 - $db_type");

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - offset with colors description authors 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - offset with colors description authors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - offset with colors description authors 3  - $db_type");

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - offset with colors description authors 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - offset with colors description authors 6  - $db_type");

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - offset with colors description authors nicknames 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - offset with colors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - offset with colors description authors nicknames 3 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - offset with colors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - offset with colors description authors nicknames 5 - $db_type");

  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - offset with colors description authors nicknames 6 - $db_type");

  $iterator = 
    $manager_class->get_products_iterator(
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 2,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  $p = $iterator->next;
  is($p->{'colors'}[0]{'name'}, 'red', "p1 - iterator with colors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'blue', "p1 - iterator with colors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p1 - iterator with colors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p1 - iterator with colors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 2', "p1 - iterator with colors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p1 - iterator with colors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p1 - iterator with colors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p1 - iterator with colors description authors 3  - $db_type");

  #$p->{'colors'}[1]{'description'}{'authors'} = 
  #  [ sort { $a->{'name'} cmp $b->{'name'} } @{$p->{'colors'}[1]{'description'}{'authors'}} ];

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'jane', "p1 - iterator with colors description authors 4 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'name'}, 'john', "p1 - iterator with colors description authors 5 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 2, "p1 - iterator with colors description authors 6  - $db_type");

  $p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p1 - iterator with colors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p1 - iterator with colors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p1 - iterator with colors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p1 - iterator with colors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p1 - iterator with colors description authors nicknames 5 - $db_type");

  $p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}} ];

  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'jack', "p1 - iterator with colors description authors nicknames 6 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[1]{'nick'}, 'sir', "p1 - iterator with colors description authors nicknames 7 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}}, 2, "p1 - iterator with colors description authors nicknames 8 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'blub', "p1 - iterator with colors description authors nicknames 9 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}}, 1, "p1 - iterator with colors description authors nicknames 10  - $db_type");

  $p = $iterator->next;
  is($p->{'colors'}[0]{'name'}, 'red', "p2 - iterator with colors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'green', "p2 - iterator with colors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p2 - iterator with colors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - iterator with colors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - iterator with colors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - iterator with colors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - iterator with colors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - iterator with colors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - iterator with colors description authors 4 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - iterator with colors description authors 6  - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - iterator with colors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - iterator with colors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - iterator with colors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - iterator with colors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - iterator with colors description authors nicknames 5 - $db_type");

  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - iterator with colors description authors nicknames 6 - $db_type");

  ok(!$iterator->next, "iterator with colors description authors nicknames 1 - $db_type");
  is($iterator->total, 2, "iterator with colors description authors nicknames 2 - $db_type");

  $iterator = 
    $manager_class->get_products_iterator(
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 1,
      offset          => 1,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  $p = $iterator->next;
  is($p->{'colors'}[0]{'name'}, 'red', "p2 - offset iterator with colors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'green', "p2 - offset iterator with colors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p2 - offset iterator with colors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - offset iterator with colors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - offset iterator with colors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - offset iterator with colors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - offset iterator with colors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - offset iterator with colors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - offset iterator with colors description authors 4 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - offset iterator with colors description authors 6  - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - offset iterator with colors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - offset iterator with colors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - offset iterator with colors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - offset iterator with colors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - offset iterator with colors description authors nicknames 5 - $db_type");

  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - offset iterator with colors description authors nicknames 6 - $db_type");

  ok(!$iterator->next, "offset iterator with colors description authors nicknames 1 - $db_type");
  is($iterator->total, 1, "offset iterator with colors description authors nicknames 2 - $db_type");

  $products = 
    $manager_class->get_products(
      require_objects => [ 'vendor.region', 'prices.region' ],
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 2,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  is($products->[0]{'vendor'}{'name'}, 'V1', "p1 - vendor 1 - $db_type");
  is($products->[0]{'vendor'}{'region'}{'name'}, 'Germany', "p1 - vendor 2 - $db_type");

  is($products->[1]{'vendor'}{'name'}, 'V2', "p2 - vendor 1 - $db_type");
  is($products->[1]{'vendor'}{'region'}{'name'}, 'America', "p2 - vendor 2 - $db_type");

  is(scalar @{$products->[0]{'prices'}}, 2, "p1 - prices 1 - $db_type");
  is(scalar @{$products->[1]{'prices'}}, 1, "p2 - prices 2 - $db_type");

  $products->[0]{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$products->[0]{'prices'}} ];
  $products->[1]{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$products->[1]{'prices'}} ];

  is($products->[0]{'prices'}[0]{'price'}, 1.23, "p1 - prices 2 - $db_type");
  is($products->[0]{'prices'}[0]{'region'}{'name'}, 'America', "p1 - prices 3 - $db_type");
  is($products->[0]{'prices'}[1]{'price'}, 4.56, "p1 - prices 4 - $db_type");
  is($products->[0]{'prices'}[1]{'region'}{'name'}, 'Germany', "p1 - prices 5 - $db_type");

  is($products->[1]{'prices'}[0]{'price'}, 9.99, "p2 - prices 2 - $db_type");
  is($products->[1]{'prices'}[0]{'region'}{'name'}, 'America', "p2 - prices 3 - $db_type");

  #$products->[0]{'colors'} = 
  #  [ sort { $b->{'name'} cmp $a->{'name'} } @{$products->[0]{'colors'}} ];

  is($products->[0]{'colors'}[0]{'name'}, 'red', "p1 - with colors vendors 1 - $db_type");
  is($products->[0]{'colors'}[1]{'name'}, 'blue', "p1 - with colors vendors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}}, 2, "p1 - with colors vendors 3  - $db_type");
  
  is($products->[0]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p1 - with colors vendors description 1 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'text'}, 'desc 2', "p1 - with colors vendors description 2 - $db_type");

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p1 - with colors vendors description authors 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p1 - with colors vendors description authors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}}, 2, "p1 - with colors vendors description authors 3  - $db_type");

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'jane', "p1 - with colors vendors description authors 4 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'name'}, 'john', "p1 - with colors vendors description authors 5 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}}, 2, "p1 - with colors vendors description authors 6  - $db_type");

  $products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $b->{'nick'} cmp $a->{'nick'} } @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'sir', "p1 - with colors vendors description authors nicknames 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'jack', "p1 - with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p1 - with colors vendors description authors nicknames 3 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p1 - with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p1 - with colors vendors description authors nicknames 5 - $db_type");

  $products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} = 
    [ sort { $b->{'nick'} cmp $a->{'nick'} } @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}} ];

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sir', "p1 - with colors vendors description authors nicknames 6 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[1]{'nick'}, 'jack', "p1 - with colors vendors description authors nicknames 7 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}}, 2, "p1 - with colors vendors description authors nicknames 8 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'blub', "p1 - with colors vendors description authors nicknames 9 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}}, 1, "p1 - with colors vendors description authors nicknames 10  - $db_type");

  is($products->[1]{'colors'}[0]{'name'}, 'red', "p2 - with colors vendors 1 - $db_type");
  is($products->[1]{'colors'}[1]{'name'}, 'green', "p2 - with colors vendors 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}}, 2, "p2 - with colors vendors 3  - $db_type");
  
  is($products->[1]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - with colors vendors description 1 - $db_type");
  is($products->[1]{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - with colors vendors description 2 - $db_type");

  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - with colors vendors description authors 1 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - with colors vendors description authors 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - with colors vendors description authors 3  - $db_type");

  is($products->[1]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - with colors vendors description authors 4 - $db_type");
  is(scalar @{$products->[1]{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - with colors vendors description authors 6  - $db_type");

  $products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} =
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - with colors vendors description authors nicknames 1 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - with colors vendors description authors nicknames 3 - $db_type");
  is($products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[1]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - with colors vendors description authors nicknames 5 - $db_type");

  is(scalar @{$products->[1]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - with colors vendors description authors nicknames 6 - $db_type");

  $products = 
    $manager_class->get_products(
      require_objects => [ 'vendor.region', 'prices.region' ],
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 1,
      offset          => 1,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  is($products->[0]{'vendor'}{'name'}, 'V2', "p2 - offset vendor 1 - $db_type");
  is($products->[0]{'vendor'}{'region'}{'name'}, 'America', "p2 - offset vendor 2 - $db_type");

  is(scalar @{$products->[0]{'prices'}}, 1, "p1 - offset prices 1 - $db_type");

  $products->[0]{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$products->[0]{'prices'}} ];

  is($products->[0]{'prices'}[0]{'price'}, 9.99, "p2 - offset prices 2 - $db_type");
  is($products->[0]{'prices'}[0]{'region'}{'name'}, 'America', "p2 - offset prices 3 - $db_type");

  is($products->[0]{'colors'}[0]{'name'}, 'red', "p2 - offset with colors vendors 1 - $db_type");
  is($products->[0]{'colors'}[1]{'name'}, 'green', "p2 - offset with colors vendors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}}, 2, "p2 - offset with colors vendors 3  - $db_type");
  
  is($products->[0]{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - offset with colors vendors description 1 - $db_type");
  is($products->[0]{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - offset with colors vendors description 2 - $db_type");

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - offset with colors vendors description authors 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - offset with colors vendors description authors 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - offset with colors vendors description authors 3  - $db_type");

  is($products->[0]{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - offset with colors vendors description authors 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - offset with colors vendors description authors 6  - $db_type");

  $products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} =
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - offset with colors vendors description authors nicknames 1 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - offset with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - offset with colors vendors description authors nicknames 3 - $db_type");
  is($products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - offset with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$products->[0]{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - offset with colors vendors description authors nicknames 5 - $db_type");

  is(scalar @{$products->[0]{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - offset with colors vendors description authors nicknames 6 - $db_type");

  $iterator = 
    $manager_class->get_products_iterator(
      require_objects => [ 'vendor.region', 'prices.region' ],
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 2,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  $p = $iterator->next;
  is($p->{'vendor'}{'name'}, 'V1', "p1 - iterator vendor 1 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'Germany', "p1 - iterator vendor 2 - $db_type");

  is(scalar @{$p->{'prices'}}, 2, "p1 - iterator prices 1 - $db_type");

  $p->{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$p->{'prices'}} ];

  is($p->{'prices'}[0]{'price'}, 1.23, "p1 - iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'region'}{'name'}, 'America', "p1 - iterator prices 3 - $db_type");
  is($p->{'prices'}[1]{'price'}, 4.56, "p1 - iterator prices 4 - $db_type");
  is($p->{'prices'}[1]{'region'}{'name'}, 'Germany', "p1 - iterator prices 5 - $db_type");

  is($p->{'colors'}[0]{'name'}, 'red', "p1 - iterator with colors vendors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'blue', "p1 - iterator with colors vendors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p1 - iterator with colors vendors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p1 - iterator with colors vendors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 2', "p1 - iterator with colors vendors description 2 - $db_type");

  #$p->{'colors'}[0]{'description'}{'authors'} = 
  #  [ sort { $a->{'name'} cmp $b->{'name'} } @{$p->{'colors'}[0]{'description'}{'authors'}} ];
    
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p1 - iterator with colors vendors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p1 - iterator with colors vendors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p1 - iterator with colors vendors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'jane', "p1 - iterator with colors vendors description authors 4 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'name'}, 'john', "p1 - iterator with colors vendors description authors 5 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 2, "p1 - iterator with colors vendors description authors 6  - $db_type");

  $p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $b->{'nick'} cmp $a->{'nick'} } @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  $p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} = 
    [ sort { $b->{'nick'} cmp $a->{'nick'} } @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}} ];

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'sir', "p1 - iterator with colors vendors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'jack', "p1 - iterator with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p1 - iterator with colors vendors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p1 - iterator with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p1 - iterator with colors vendors description authors nicknames 5 - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sir', "p1 - iterator with colors vendors description authors nicknames 6 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}[1]{'nick'}, 'jack', "p1 - iterator with colors vendors description authors nicknames 7 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'}}, 2, "p1 - iterator with colors vendors description authors nicknames 8 - $db_type");
  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'blub', "p1 - iterator with colors vendors description authors nicknames 9 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[0]{'nicknames'}}, 1, "p1 - iterator with colors vendors description authors nicknames 10  - $db_type");

  $p = $iterator->next;
  is($p->{'vendor'}{'name'}, 'V2', "p2 - iterator vendor 1 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'America', "p2 - iterator vendor 2 - $db_type");

  $p->{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$p->{'prices'}} ];
  
  is(scalar @{$p->{'prices'}}, 1, "p2 - iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'price'}, 9.99, "p2 - iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'region'}{'name'}, 'America', "p2 - iterator prices 3 - $db_type");

  is($p->{'colors'}[0]{'name'}, 'red', "p2 - iterator with colors vendors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'green', "p2 - iterator with colors vendors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p2 - iterator with colors vendors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - iterator with colors vendors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - iterator with colors vendors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - iterator with colors vendors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - iterator with colors vendors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - iterator with colors vendors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - iterator with colors vendors description authors 4 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - iterator with colors vendors description authors 6  - $db_type");

  $p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - iterator with colors vendors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - iterator with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - iterator with colors vendors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - iterator with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - iterator with colors vendors description authors nicknames 5 - $db_type");

  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - iterator with colors vendors description authors nicknames 6 - $db_type");

  $iterator = 
    $manager_class->get_products_iterator(
      require_objects => [ 'vendor.region', 'prices.region' ],
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      limit           => 1,
      offset          => 1,
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  $p = $iterator->next;
  is($p->{'vendor'}{'name'}, 'V2', "p2 - offset iterator vendor 1 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'America', "p2 - offset iterator vendor 2 - $db_type");

  $p->{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$p->{'prices'}} ];
  
  is(scalar @{$p->{'prices'}}, 1, "p2 - offset iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'price'}, 9.99, "p2 - offset iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'region'}{'name'}, 'America', "p2 - offset iterator prices 3 - $db_type");

  is($p->{'colors'}[0]{'name'}, 'red', "p2 - offset iterator with colors vendors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'green', "p2 - offset iterator with colors vendors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p2 - offset iterator with colors vendors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - offset iterator with colors vendors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - offset iterator with colors vendors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - offset iterator with colors vendors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - offset iterator with colors vendors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - offset iterator with colors vendors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - offset iterator with colors vendors description authors 4 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - offset iterator with colors vendors description authors 6  - $db_type");

  $p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} = 
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - offset iterator with colors vendors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - offset iterator with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - offset iterator with colors vendors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - offset iterator with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - offset iterator with colors vendors description authors nicknames 5 - $db_type");

  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - offset iterator with colors vendors description authors nicknames 6 - $db_type");

  ok(!$iterator->next, "offset iterator with colors vendors description authors nicknames 1 - $db_type");
  is($iterator->total, 1, "offset iterator with colors vendors description authors nicknames 2 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $iterator = 
    $manager_class->get_products_iterator(
      require_objects => [ 'vendor.region', 'prices.region' ],
      with_objects    => [ 'colors.description.authors.nicknames' ],
      multi_many_ok   => 1,
      query           => [ 'vendor.region.name' => 'America' ],
      sort_by => [ 'colors.name DESC', 'authors.name' ]);

  $p = $iterator->next;
  is($p->{'vendor'}{'name'}, 'V2', "p2 - query iterator vendor 1 - $db_type");
  is($p->{'vendor'}{'region'}{'name'}, 'America', "p2 - query iterator vendor 2 - $db_type");

  $p->{'prices'} = [ sort { $a->{'price'} <=> $b->{'price'} } @{$p->{'prices'}} ];
  
  is(scalar @{$p->{'prices'}}, 1, "p2 - query iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'price'}, 9.99, "p2 - query iterator prices 2 - $db_type");
  is($p->{'prices'}[0]{'region'}{'name'}, 'America', "p2 - query iterator prices 3 - $db_type");

  is($p->{'colors'}[0]{'name'}, 'red', "p2 - query iterator with colors vendors 1 - $db_type");
  is($p->{'colors'}[1]{'name'}, 'green', "p2 - query iterator with colors vendors 2 - $db_type");
  is(scalar @{$p->{'colors'}}, 2, "p2 - query iterator with colors vendors 3  - $db_type");
  
  is($p->{'colors'}[0]{'description'}{'text'}, 'desc 1', "p2 - query iterator with colors vendors description 1 - $db_type");
  is($p->{'colors'}[1]{'description'}{'text'}, 'desc 3', "p2 - query iterator with colors vendors description 2 - $db_type");

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'name'}, 'john', "p2 - query iterator with colors vendors description authors 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'name'}, 'sue', "p2 - query iterator with colors vendors description authors 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}}, 2, "p2 - query iterator with colors vendors description authors 3  - $db_type");

  is($p->{'colors'}[1]{'description'}{'authors'}[0]{'name'}, 'tim', "p2 - query iterator with colors vendors description authors 4 - $db_type");
  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}}, 1, "p2 - query iterator with colors vendors description authors 6  - $db_type");

  $p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'} =
    [ sort { $a->{'nick'} cmp $b->{'nick'} } @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}} ];

  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[0]{'nick'}, 'jack', "p2 - query iterator with colors vendors description authors nicknames 1 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}[1]{'nick'}, 'sir', "p2 - query iterator with colors vendors description authors nicknames 2 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[0]{'nicknames'}}, 2, "p2 - query iterator with colors vendors description authors nicknames 3 - $db_type");
  is($p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}[0]{'nick'}, 'sioux', "p2 - query iterator with colors vendors description authors nicknames 4 - $db_type");
  is(scalar @{$p->{'colors'}[0]{'description'}{'authors'}[1]{'nicknames'}}, 1, "p2 - query iterator with colors vendors description authors nicknames 5 - $db_type");

  is(scalar @{$p->{'colors'}[1]{'description'}{'authors'}[1]{'nicknames'} || []}, 0, "p2 - query iterator with colors vendors description authors nicknames 6 - $db_type");

  ok(!$iterator->next, "query iterator with colors vendors description authors nicknames 1 - $db_type");
  is($iterator->total, 1, "query iterator with colors vendors description authors nicknames 2 - $db_type");
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

    my $version = $dbh->get_info(18); # SQL_DBMS_VER  

    die "MySQL version too old"  unless($version =~ /^4\./);

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
