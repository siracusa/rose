package My::Auto::Product;
use strict;
use base 'My::Object';
__PACKAGE__->meta->relationships
(
  prices => { type => 'one to many' },
  colors => { type => 'many to many' },
);
__PACKAGE__->meta->auto_initialize;
1;
