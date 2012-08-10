package My::DB::Opa;
use base qw(Rose::DB);
use strict;
use warnings;

use File::Temp qw/ tempfile /;
my ($fh, $filename) = tempfile();

my $CONN_COUNT;

# hook
sub init_dbh {
  $CONN_COUNT++;
  return shift->SUPER::init_dbh(@_);
}

sub _conn_count {
  my ($self, $val) = @_;
  return defined $val ? $CONN_COUNT = $val : $CONN_COUNT;
}


__PACKAGE__->use_private_registry;
__PACKAGE__->register_db(driver => 'sqlite', database => $filename,);


CREATE: {
  my $dbh = __PACKAGE__->new()->retain_dbh;
  $dbh->do('DROP TABLE IF EXISTS `sites`');
  $dbh->do(<<CREATE);
CREATE TABLE `sites` (
  `id` int(10) NOT NULL,
  `host` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
)
CREATE


}

# reset the counter
_conn_count(__PACKAGE__, 0);

1;
