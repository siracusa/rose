package My::DB::Opa::Object;
use parent 'Rose::DB::Object';
use My::DB::Opa;

use strict;
use warnings;

# CACHED!!!
sub init_db {
  return My::DB::Opa->new_or_cached;
}

1;
