package Rose::WebSite::User::Session::Storage::MySQL;

use strict;

use Apache::Session;
our @ISA = qw(Apache::Session);

use Rose::WebSite::User::Session::Generate::SHA1;

use Apache::Session::Lock::Null;
use Apache::Session::Store::MySQL;
use Apache::Session::Serialize::Storable;

sub populate
{
  my($self) = shift;

  $self->{'object_store'} = Apache::Session::Store::MySQL->new($self);
  $self->{'lock_manager'} = Apache::Session::Lock::Null->new($self);
  $self->{'generate'}     = \&Rose::WebSite::User::Session::Generate::SHA1::generate;
  $self->{'validate'}     = \&Rose::WebSite::User::Session::Generate::SHA1::validate;
  $self->{'serialize'}    = \&Apache::Session::Serialize::Storable::serialize;
  $self->{'unserialize'}  = \&Apache::Session::Serialize::Storable::unserialize;

  return $self;
}

# Using null lock manager (see above), so this is a no-op
#sub DESTROY { $_[0]->release_all_locks }

sub DESTROY { }

1;
