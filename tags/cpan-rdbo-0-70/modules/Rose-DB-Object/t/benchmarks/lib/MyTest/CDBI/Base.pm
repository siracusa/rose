package MyTest::CDBI::Base;

use strict;

use Rose::DB;

use base 'Class::DBI';

our $DB;

sub refresh
{
  $DB = Rose::DB->new;
  no strict;
  __PACKAGE__->connection($DB->dsn, $DB->username, $DB->password, scalar $DB->connect_options);   
}

1;