package Rose::HTML::Object::Repeatable;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.554';

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'count',
    'default_count',
    'entity',
    'entity_spec',
  ],
);

1;
