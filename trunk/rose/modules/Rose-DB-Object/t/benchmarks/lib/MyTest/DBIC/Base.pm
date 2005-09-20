package MyTest::DBIC::Base;

use strict;

use Rose::DB;

use base qw(DBIx::Class);
__PACKAGE__->load_components(qw(Core DB));

our $DB;

sub refresh
{
  $DB = Rose::DB->new;
  no warnings;
  __PACKAGE__->connection($DB->dsn, $DB->username, $DB->password, scalar $DB->connect_options);   
}

1;
