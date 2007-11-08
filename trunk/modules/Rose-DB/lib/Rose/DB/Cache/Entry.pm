package Rose::DB::Cache::Entry;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.736';

use Rose::Object::MakeMethods::Generic
(
  'scalar'  => 
  [
    'db',
    'key',
  ],

  'boolean' => 
  [
    'prepared',
    'created_during_apache_startup',
  ]
);

*is_prepared = \&prepared;

1;
