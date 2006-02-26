package MyTest::DBIC::Simple::Product;

use strict;

use MyTest::DBIC::Simple::Code;
use MyTest::DBIC::Simple::Category;

use base 'MyTest::DBIC::Base';

__PACKAGE__->table('rose_db_object_test_products');
__PACKAGE__->add_columns(qw(category_id date_created fk1 fk2 fk3 id last_modified name published status));
__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_relationship('category_id', 'MyTest::DBIC::Simple::Category',
                            { 'foreign.id' => 'self.category_id' },
                            { accessor => 'filter' });

1;