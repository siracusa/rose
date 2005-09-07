package Rose::Apache;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::Apache0',
    mp1 => 'Rose::Apache1', 
    mp2 => 'Rose::Apache2',
  );
}

1;
