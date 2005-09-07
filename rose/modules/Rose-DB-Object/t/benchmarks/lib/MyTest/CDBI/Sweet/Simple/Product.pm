package MyTest::CDBI::Sweet::Simple::Product;

use strict;

use MyTest::CDBI::Sweet::Simple::Code;
use MyTest::CDBI::Sweet::Simple::Category;

use base 'MyTest::CDBI::Sweet::Base';

__PACKAGE__->table('rose_db_object_test_products');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw(category_id date_created fk1 fk2 fk3 id last_modified name published status));

__PACKAGE__->has_a(category_id => 'MyTest::CDBI::Sweet::Simple::Category');

1;