# Rose::DB subclass to handle the db connection
package My::DB;
use strict;
use base 'Rose::DB';

use Rose::DB::Registry;
__PACKAGE__->registry(Rose::DB::Registry->new);
         
My::DB->register_db
(
  type     => 'default',
  domain   => 'default',
  driver   => 'Pg',
  database => 'test',
  username => 'postgres',
);

1;
