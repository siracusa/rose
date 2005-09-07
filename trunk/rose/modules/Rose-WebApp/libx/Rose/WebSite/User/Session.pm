package Rose::WebSite::User::Session;

use strict;

use Carp;

use Apache;
use Apache::Cookie;

use Rose::WebSite;

use Rose::WebSite::User::Session::Storage::MySQL;

use Rose::WebSite::User::Session::Conf qw(%CONF);
use Rose::WebSite::Server::Conf qw(%SITE_CONF);

use Rose::Object;
our @ISA = qw(Rose::Object);

use constant TRANSACTION_TIMEOUT => 60 * 10; # seconds

use constant LOGIN_REFRESH  => Apache->server->dir_config('RoseLoginRefresh') ||
                              $CONF{'LOGIN_REFRESH'};

use constant LOGIN_DURATION => Apache->server->dir_config('RoseLoginDuration') ||
                               $CONF{'LOGIN_DURATION'};

our $Cookie_Set_For_Req_Num;

our $Debug = 0;

use Class::MakeMethods::Template::Hash
(
  'scalar' => [ 'error' ],
);

sub new
{
  my($class) = shift;

  my $self =
  {
    data => 
    {
      is_anonymous     => undef,

      user_id          => undef,
      user_type        => undef,

      username         => undef,
      password         => undef,

      email            => undef,
      first_name       => undef,
      last_name        => undef,

      auth_credentials => undef,

      logged_in        => undef,
      login_time       => undef,
      login_duration   => undef,
      login_expired    => undef,

      updated          => undef,

      stash            => {},

      group_membership           => undef,
      group_membership_load_time => undef,
    },

    error => undef,
  };

  bless $self, $class;

  $self->init(@_);

  return $self;
}

sub init
{
  my($self) = shift;

  $self->SUPER::init(@_);

  return $self->load();
}

sub store
{
  my($self) = shift;

  die "Cannot store unloaded session"  unless(tied %{$self->{'data'}});
  #$Debug &&  warn "$$ $self storing $self->{'data'}{'_session_id'} for $self->{'data'}{'username'} $self->{'data'}{'logged_in'}\n",
  #Carp::cluck();
  #join(', ', (caller(1))[1,2,3]), "\n\n";
  #Data::Dumper::Dumper($self->{'data'});

  tied(%{$self->{'data'}})->save;

  #untie %{$self->{'data'}}; # old way...

  return 1;
}

sub make_modified
{
  my $session = tied(%{$_[0]->{'data'}}) or return;
  #$Debug && warn "$_[0] make_modified()\nXXX ", join(', ', (caller(0))[1,2,3]), "\n";
  $session->make_modified
}

sub store_if_modified
{
  my($self) = shift;

  my $session = tied(%{$self->{'data'}});

  if($session && $session->is_modified)
  {
    #$Debug && warn __PACKAGE__, " store_if_modified: SAVING MODIFIED SESSION\n";
    #Data::Dumper::Dumper($session);
    $self->store();
  }
  #else {  warn __PACKAGE__, " store_if_modified: SESSION NOT MODIFIED\n" }

  return 1;
}

sub save
{
  my($self) = shift;

  $self->store_if_modified or return undef;
  $self->load  or return undef;

  return 1;
}

# All saves are explicit.  Saving during destruction causes more
# problems than it solves... :-/
sub DESTROY { }

sub load
{
  my($self) = shift;

  my $id = $self->id;

  unless($id)
  {
    my $cookies = Apache::Cookie->fetch();
    my $name = $self->id_cookie_name;

    if(exists $cookies->{$name})
    {
      $id = $cookies->{$name}->value;
    }
    else
    {
      Rose::WebSite->session_cookie_missing(1);
    }
  }

  GET_SESSION:
  {
    eval
    {
      tie(%{$self->{'data'}}, 'Rose::WebSite::User::Session::Storage::MySQL', $id, 
      {
        DataSource => $CONF{'DB_DSN'},
        UserName   => $CONF{'DB_USERNAME'},
        Password   => $CONF{'DB_PASSWORD'},
      });
    };

    if($@) 
    {
      if($id)
      {
        $self->error("Could not retrieve session id $id: $@");
        Apache->request->log_error($self->error);

        $id = undef;

        redo GET_SESSION;
      }
      else
      {
        $self->error("Could not create new session: $@");
        Apache->request->log_error($self->error);
        return;
      }
    }
  }

  unless($id)
  {
    $self->set_cookie;
  }

  #$Debug && warn "$$ $self loaded $self->{'data'}{'_session_id'} for $self->{'data'}{'username'}\n";
  return 1;
}

sub default_login_duration { LOGIN_DURATION }

sub login_is_expired
{
  my($self) = shift;

  my $current_time   = time;
  my $login_time     = $self->login_time;
  my $login_duration = $self->login_duration;

  if($login_time && $login_duration)
  {
    unless($current_time - $login_time <= $login_duration)
    {
      return $self->login_expired(1);
    }
  }

  return 0;
}

sub is_logged_in
{
  my($self) = shift;

  my $current_time   = time;
  my $login_time     = $self->login_time;
  my $login_duration = $self->login_duration;

  if($login_time && $login_duration)
  {
    if($current_time - $login_time <= $login_duration)
    {
      # Conditionally update login time 
      if(LOGIN_REFRESH && $current_time != $login_time && 
         $login_duration / ($current_time - $login_time) < LOGIN_REFRESH)
      {
        $Debug && warn "$self updating login time.\n";
        $self->login_time(time);
      }

      return 1;
    }
    else { $self->login_expired(1) }
  }

  return;
}

sub cookie
{
  my($self, $r) = @_;

  $r ||= Apache->request;

  my $expires = $self->id_cookie_expires;

  return  
    Apache::Cookie->new($r, -name    => $self->id_cookie_name,
                            -value   => $self->id,
                            -domain  => $self->id_cookie_domain,
                            -secure  => $self->id_cookie_is_secure,
                            -path    => '/',
                            ($expires ? (-expires => $expires) : ()));
}

sub id_cookie_is_secure { 0 }
sub id_cookie_name    { $CONF{'ID_COOKIE'} }
sub id_cookie_domain  { $SITE_CONF{'SERVER_NAME'} }
sub id_cookie_expires { '+1y' }

sub set_cookie
{
  my($self, %args) = @_;

  my $r = Apache->request;
  my $n = Rose::WebSite->request_number;

  #print STDERR "return 1  if($n == $Cookie_Set_For_Req_Num);\n";
  return 1  if($n == $Cookie_Set_For_Req_Num);

  $Cookie_Set_For_Req_Num = $n;

  #print STDERR "BAKE\n";
  $self->cookie($r)->bake;
}

sub _session_data
{
  my($self)   = shift;
  my($param)  = shift;

  if(@_)
  {
    my $val = shift;

    if(exists $self->{'data'}{$param} && $self->{'data'}{$param} eq $val)
    {
      return $val;
    }

    #$Debug && warn "$self set session $param = ", Data::Dumper::Dumper($val);#\n";
    #$Debug && warn "$self set session $param = $val\n";
    return $self->{'data'}{$param} = $val;
  }

  return $self->{'data'}{$param};
}

sub stash
{
  my($self) = shift;

  return $self->{'data'}{'stash'}  unless(@_);

  if(@_ == 1)
  {
    $self->make_modified;
    return $self->{'data'}{'stash'} = shift;
  }

  my %args = @_;

  my $domain = $args{'domain'} or croak "Missing domain argument";
  my $param  = $args{'name'}   or croak "Missing name argument";

  if(exists $args{'value'})
  {
    if(!exists $self->{'data'}{'stash'}{$domain}{$param} ||
       !defined $args{'value'} || 
       $self->{'data'}{'stash'}{$domain}{$param} ne $args{'value'})
    {
      $self->make_modified;
    }

    #$Debug && warn "Session stash set $domain $param = $args{'value'}\n";
    return $self->{'data'}{'stash'}{$domain}{$param} = $args{'value'};
  }

  if(exists $self->{'data'}{'stash'}{$domain} &&
     exists $self->{'data'}{'stash'}{$domain}{$param})
  {
    #$Debug && warn "Session stash get $domain $param: $self->{'data'}{'stash'}{$domain}{$param}\n";
    return $self->{'data'}{'stash'}{$domain}{$param};
  }

  return undef;
}

sub clear_stash
{
  my($self) = shift;

  if(@_ == 1)
  {
    $self->{'data'}{'stash'} = {};
    $self->make_modified;
    return $self->{'data'}{'stash'};
  }

  my %args = @_;

  my $domain = $args{'domain'} or croak "Missing domain argument";

  if(exists $args{'name'} && defined $args{'name'})
  {
    delete $self->{'data'}{'stash'}{$domain}{$args{'name'}};
    $self->make_modified;
    return 1;
  }

  delete $self->{'data'}{'stash'}{$domain};
  $self->make_modified;
  return 1;
}

sub id               { shift->_session_data('_session_id', @_) }

sub is_anonymous     { shift->_session_data('is_anonymous', @_)  }

sub user_id          { shift->_session_data('user_id', @_)  }
sub username         { shift->_session_data('username', @_) }
sub password         { shift->_session_data('password', @_) }
sub password_encrypted { shift->_session_data('password_encrypted', @_) }

sub preferences      { shift->_session_data('preferences', @_) }

sub email            { shift->_session_data('email', @_) }
sub first_name       { shift->_session_data('first_name', @_) }
sub last_name        { shift->_session_data('last_name', @_) }

sub logged_in        { shift->_session_data('logged_in', @_) }
sub login_time       { shift->_session_data('login_time', @_) }
sub login_duration   { shift->_session_data('login_duration', @_) }
sub login_expired    { shift->_session_data('login_expired', @_) }

sub auth_credentials { shift->_session_data('auth_credentials', @_) }

sub rose_user_type    { shift->_session_data('rose_user_type', @_) }

sub group_membership_load_time { shift->_session_data('group_membership_load_time', @_) }

sub referrer_id_set { shift->_session_data('referrer_id_set', @_) }

sub referrer_id
{
  my($self) = shift;

  my $ref_id = $self->_session_data('referrer_id');

  return $ref_id  unless(@_);

  my $set_ref_id = shift;

  if($set_ref_id != $ref_id)
  {
    $self->_session_data('referrer_id' => $set_ref_id);
    $self->_session_data('referrer_id_set' => time);
    return $set_ref_id;
  }

  return $ref_id;
}

sub login
{
  my($self, $user) = @_;

  #
  # Set common session data
  #

  foreach my $param (qw(user_id username email first_name last_name password_encrypted))
  {
    $Debug && warn "$self set $param = ", $user->$param(), "\n";
    $self->$param($user->$param());
  }

  $self->is_anonymous(0);

  $self->login_duration($self->default_login_duration);
  $self->login_expired(0);
  $self->login_time(time);

  return 1;
}

sub logout
{
  my($self, %args) = @_;

  my $data = $self->{'data'};

  $self->auth_credentials(undef);
  $self->logged_in(0);

  # Uncomment this to clear all session data
  #foreach my $key (grep { $_ ne '_session_id' } keys %{$data})
  #{
  #  $data->{$key} = undef;
  #}

  # Uncomment this to delete the session when a user logs out
  #tied(%{$self->{'data'}})->delete;

  # Uncomment this to delete the session cookie when a user logs out
  #$self->id('');
  #$self->cookie->bake;

  if(!$args{'delay_session_store'} && (ref $self eq __PACKAGE__ || !defined &{ref($self) . '::logout'}))
  {
    #$Debug && warn __PACKAGE__, " store session\n";
    # Store is a destructive operation (because it unties the session data hash),
    # so we must reload the session if we want to keep it around (and we do).
    $self->store or warn "Could not store session: ", $self->error;
    $self->load  or warn "Could not reload session: ", $self->error;
  }

  return 1;
}


1;
