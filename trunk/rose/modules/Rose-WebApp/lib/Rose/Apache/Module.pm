package Rose::Apache::Module;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::Apache0::Module',
    mp1 => 'Rose::Apache1::Module',
    mp2 => 'Rose::Apache2::Module',
  );
}

1;