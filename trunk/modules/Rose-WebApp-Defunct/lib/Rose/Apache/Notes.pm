package Rose::Apache::Notes;

use strict;

BEGIN
{
  use Rose::Apache::Version;
  Rose::Apache::Version::choose_super
  (
    mp0 => 'Rose::Apache1::Notes',
    mp1 => 'Rose::Apache1::Notes',
    mp2 => 'Rose::Apache2::Notes',
  );
}

1;
