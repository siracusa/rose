package MyTest::DBIC::Base;

use strict;

use Rose::DB;

use base qw(DBIx::Class);
__PACKAGE__->load_components(qw(Core DB));

sub refresh
{
  my $db = Rose::DB->new;
  no warnings;
  __PACKAGE__->connection($db->dsn, $db->username, $db->password, scalar $db->connect_options);   
}

1;
