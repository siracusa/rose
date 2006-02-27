package Rose::Apache::Constants;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::Apache0::Constants',
    mp1 => 'Rose::Apache1::Constants', 
    mp2 => 'Rose::Apache2::Constants',
  );
}

1;
