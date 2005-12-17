package MyTest::CDBI::Sweet::Base;

use strict;

use Rose::DB;

use base 'Class::DBI::Sweet';

sub refresh
{
  my $db = Rose::DB->new;
  no strict;
  __PACKAGE__->connection($db->dsn, $db->username, $db->password, scalar $db->connect_options);   
}

1;