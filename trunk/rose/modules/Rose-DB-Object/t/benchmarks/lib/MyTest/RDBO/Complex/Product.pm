package MyTest::RDBO::Complex::Product;

use strict;

use MyTest::RDBO::Complex::Code;
use MyTest::RDBO::Complex::Category;

use Rose::DB::Object;
our @ISA = qw(Rose::DB::Object);

__PACKAGE__->meta->table('rose_db_object_test_products');

# Set up manually so we can force the accessor name
__PACKAGE__->meta->foreign_keys
(
  category =>
  {
    class => 'MyTest::RDBO::Complex::Category',
    key_columns =>
    {
      category_id => 'id',
    }
  },

  code =>
  {
    class => 'MyTest::RDBO::Complex::Code',
    key_columns =>
    {
      fk1 => 'k1',
      fk2 => 'k2',
      fk3 => 'k3',
    }
  }
);

__PACKAGE__->meta->auto_initialize;

1;