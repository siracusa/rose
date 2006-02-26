package MyTest::DBIC::Complex::Category;

use strict;

use base 'MyTest::DBIC::Base';

__PACKAGE__->table('rose_db_object_test_categories');
__PACKAGE__->add_columns(qw(id name));
__PACKAGE__->set_primary_key('id');

1;
