package Rose::DB::Cache;

use strict;

use Rose::DB::Cache::Entry;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.736';

our $Debug = 1;

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'entry_class',
  ]
);

__PACKAGE__->entry_class('Rose::DB::Cache::Entry');

sub cache_key_from_args
{
  my($class, %args) = @_;
  return join("\0", $args{'domain'}, $args{'type'});
}

sub get_db
{
  my($self) = shift;
my %args = @_;

unless($args{'domain'})
{
  Carp::cluck('Missing domain');
}
  my $key = $self->cache_key_from_args(@_);
  
  if(my $entry = $self->{'cache'}{$key})
  {
    if(my $db = $entry->db)
    {
      $self->prepare_db($db, $entry);
      return $db;
    }
  }

  return undef;
}

sub set_db
{
  my($self, $db) = @_;
  
  my $key = 
    $self->cache_key_from_args(domain => $db->domain, 
                               type   => $db->type,
                               db     => $db);

  my $entry = ref($self)->entry_class->new(db => $db, key => $key);

  $self->{'cache'}{$key} = $entry;

  return $db;
}

sub clear { shift->{'cache'} = {} }

QUIET:
{
  no warnings 'uninitialized';
  use constant APACHE_DBI     => ($INC{'Apache/DBI.pm'} || $Apache::DBI::VERSION)    ? 1 : 0;
  use constant APACHE_DBI_MP2 => (APACHE_DBI && $ENV{'MOD_PERL_API_VERSION'} == 2)   ? 1 : 0;
  use constant APACHE_DBI_MP1 => (APACHE_DBI && $ENV{'MOD_PERL'} && !APACHE_DBI_MP2) ? 1 : 0;
}

if(APACHE_DBI_MP2)
{
  require Apache2::ServerUtil;
}

sub prepare_db
{
  my($self, $db, $entry) = @_;

  if(APACHE_DBI_MP1)
  {
    if($Apache::Server::Starting)
    {
      $entry->created_during_apache_startup(1);
      $entry->prepared(0);
    }
    elsif(!$entry->is_prepared)
    {
      if($entry->created_during_apache_startup)
      {
        $Debug && $db->has_dbh && warn "$$ Wiping dbh ", $db->dbh, 
          " created during apache startup from $db\n";
        $db->dbh(undef);
        $entry->created_during_apache_startup(0);
        return;
      }

      Apache->push_handlers(PerlCleanupHandler => sub
      {
        $Debug && warn "$$ Clear dbh and prepared flag for $db, $entry\n";
        $db->dbh(undef)      if($db);
        $entry->prepared(0)  if($entry);
      });

      $entry->prepared(1);
    }
  }

  # Not a chained elsif to help Perl eliminate the unused code (maybe unnecessary?)
  if(APACHE_DBI_MP2)
  {
    if(Apache2::ServerUtil::restart_count() == 1) # server starting
    {
      $entry->created_during_apache_startup(1);
      $entry->prepared(0);
    }
    elsif(!$entry->is_prepared)
    {
      if($entry->created_during_apache_startup)
      {
        $Debug && $db->has_dbh && warn "$$ Wiping dbh ", $db->dbh, 
          " created during apache startup from $db\n";
        $db->dbh(undef);
        $entry->created_during_apache_startup(0);
        return;
      }

      Apache2::ServerUtil->server->push_handlers(PerlCleanupHandler => sub
      {
        $Debug && warn "$$ Clear dbh and prepared flag for $db, $entry\n";
        $db->dbh(undef)      if($db);
        $entry->prepared(0)  if($entry);
      });

      $entry->prepared(1);
    }
  }
}

1;
