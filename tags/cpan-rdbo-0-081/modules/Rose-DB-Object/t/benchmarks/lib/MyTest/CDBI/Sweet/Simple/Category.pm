package MyTest::CDBI::Sweet::Simple::Category;

use strict;

use base 'MyTest::CDBI::Sweet::Base';

__PACKAGE__->table('rose_db_object_test_categories');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw(id name));

1;