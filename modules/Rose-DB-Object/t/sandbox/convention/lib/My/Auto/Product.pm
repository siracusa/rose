package My::Auto::Product;
use strict;
use base 'My::Object';
__PACKAGE__->meta->relationships
(
  prices => 'one to many',
  colors => 'many to many',
);
__PACKAGE__->meta->auto_initialize;
1;
