package MyTest::DBIC::Complex::Code;

use strict;

use base 'MyTest::DBIC::Base';

__PACKAGE__->table('rose_db_object_test_code_names');
__PACKAGE__->add_columns(qw(id product_id name));
__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_relationship('product_id', 'MyTest::DBIC::Complex::Product',
                            { 'foreign.id' => 'self.product_id' },
                            { accessor => 'filter' });

1;