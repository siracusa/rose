package MyTest::RDBO::Simple::Category;

use strict;

use Rose::DB::Object;
our @ISA = qw(Rose::DB::Object);

__PACKAGE__->meta->table('rose_db_object_test_categories');
__PACKAGE__->meta->columns(qw(id name));
__PACKAGE__->meta->primary_key_columns([ 'id' ]);
__PACKAGE__->meta->initialize;

1;
