package Rose::DB::Cache;

use strict;

use base 'Rose::Object';

use Rose::DB::Cache::Entry;

our $VERSION = '0.736';

our $Debug = 0;

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'entry_class',
  ]
);

__PACKAGE__->entry_class('Rose::DB::Cache::Entry');

sub build_cache_key
{
  my($class, %args) = @_;
  return join("\0", $args{'domain'}, $args{'type'});
}

sub get_db
{
  my($self) = shift;

  my $key = $self->build_cache_key(@_);

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
    $self->build_cache_key(domain => $db->domain, 
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

__END__

=head1 NAME

Rose::DB::Cache - A cache for Rose::DB objects.

=head1 SYNOPSIS

  # Usage
  package My::DB;

  use base 'Rose::DB';
  ...

  $cache = My::DB->db_cache;

  $db = $cache->get_db(...);

  $cache->set_db($db);

  $cache->clear;


  # Subclassing
  package My::DB::Cache;

  use Rose::DB::Cache;
  our @ISA = qw(Rose::DB::Cache);

  # Override methods as desired
  sub get_db          { ... }
  sub set_db          { ... }
  sub prepare_db      { ... }
  sub build_cache_key { ... }
  sub clear           { ... }

=head1 DESCRIPTION

L<Rose::DB::Cache> provides both an API and a default implementation of a caching system for L<Rose::DB> objects.  Each L<Rose::DB>-derived class L<references|Rose::DB/db_cache> a L<Rose::DB::Cache>-derived object to which it delegates cache-related activites.  See the L<new_or_cached|Rose::DB/new_or_cached> method for an example.

The default implementation caches and returns L<Rose::DB> objects using the combination of their L<type|Rose::DB/type> and L<domain|Rose::DB/domain> as the cache key.  There is no cache expiration or other cache cleaning.  The only sophistication in the default implementation is that it is L<Apache::DBI>-aware: it will do the right thing during apache server start-up and will ensure that L<Apache::DBI>'s "ping" and rollback features work as expected, keeping the L<DBI> database handles L<contained|Rose::DB/dbh> within each L<Rose::DB> object connected and alive.  Bot mod_perl 1.x and 2.x are supported.

Subclasses can override any and all methods described below in order to implement their own caching strategy.

=head1 CLASS METHODS

=over 4

=item B<build_cache_key PARAMS>

Given the name/value pairs PARAMS, return a string representing the corresponding cache key.  Calls to this method from within L<Rose::DB::Cache> will include at least C<type> and C<domain> parameters, but you may pass any parameters if you override all methods that call this method in your subclass.

=item B<entry_class [CLASS]>

Get or set the name of the L<Rose::DB::Cache::Entry>-derived class used to store cached L<Rose::DB> objects on behalf of this class.  The default value is L<Rose::DB::Cache::Entry>.

=back

=head1 CONSTRUCTORS

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::DB::Cache> object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<clear>

Clears the cache entirely.

=item B<get_db [PARAMS]>

Return the cached L<Rose::DB>-derived object corresponding to the name/value pairs passed in PARAMS.  PARAMS are passed to the L<build_cache_key|/build_cache_key> method, and the key returned is used to look up the cached object.

If a cached object is found, the L<prepare_db|/prepare_db> method is called, passing the cached db object and its corresponding L<Rose::DB::Cache::Entry> object as arguments.  The cached db object is then returned.

If no such object exists in the cache, undef is returned.

=item B<prepare_db [DB, ENTRY]>

Prepare the cached L<Rose::DB>-derived object DB for usage.  The cached's db object's L<Rose::DB::Cache::Entry> object, ENTRY, is also passed.

When I<NOT> running under L<Apache::DBI>, this method does nothing.

When running under L<Apache::DBI>, using either mod_perl 1.x or 2.x, this method will do the following:

=over 4

=item * Any L<DBI> database handle created inside a L<Rose::DB> object during apache server startup will be discarded and replaced the first time it is used after server startup has completed.

=item * All L<DBI> database handles contained in cached L<Rose::DB> objects will be cleared at the end of each request using a C<PerlCleanupHandler>.  This will cause L<DBI-E<gt>connect|DBI/connect> to be called the next time a L<dbh|Rose::DB/dbh> is requested from a cached L<Rose::DB> object, which in turn will trigger L<Apache::DBI>'s ping mechanism to ensure that the database handle is fresh.

=back

Putting all the pieces together, the following implementation of the L<init_db|Rose::DB::Object/init_db> method in your L<Rose::DB::Object>-derived common base class will ensure that database connections are shared and fresh under L<mod_perl> and L<Apache::DBI>, but unshared elsewhere:

  package My::DB::Object;

  use base 'Rose::DB::Object';

  use My::DB; # isa Rose::DB
  ...

  BEGIN:
  {
    if($ENV{'MOD_PERL'})
    {
      *init_db = sub { My::DB->new_or_cached };
    }
    else # act "normally" when not under mod_perl
    {
      *init_db = sub { My::DB->new };
    }
  }

=item B<set_db DB>

Add the L<Rose::DB>-derived object DB to the cache.  The DB's L<domain|Rose::DB/domain>, L<type|Rose::DB/type>, and the db object itself (under the param name C<db>) are all are passed to the L<build_cache_key|/build_cache_key> method and the DB object is stored under the key returned.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 COPYRIGHT

Copyright (c) 2007 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
