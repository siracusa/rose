package Rose::WebSite::User;

use strict;

use Carp;

use Rose::User;
use Rose::Users;

use Rose::WebSite::User::Auth;
use Rose::WebSite::User::Session;

use Rose::WebSite::User::Conf qw(%CONF);

use Rose::Object;
use Rose::User::WithPreferences;
our @ISA = qw(Rose::Object Rose::User::WithPreferences);

use constant LOGIN_REFRESH => 
  Apache->server->dir_config('RoseLoginRefresh') ||
  $CONF{'LOGIN_REFRESH'};

use constant USER_GROUPS_REFRESH =>
  Apache->server->dir_config('RoseUserGroupsRefresh') ||
  $CONF{'USER_GROUPS_REFRESH'};

use constant FAKE_AUTH => Apache->server->dir_config('RoseFakeAuth') || 0;

our $Debug = 0;

use Class::MakeMethods::Template::Hash
(
  'scalar' => 
  [
    'session',
    'error',
  ],
);

sub init
{
  my($self) = shift;

  $self->SUPER::init(@_);

  $self->init_session();

  $Debug && warn "$self session id = ", $self->session->id, "\n";
}

sub init_session
{
  my($self) = shift;

  $self->session(Rose::WebSite::User::Session->new)  unless($self->session);
}

sub nice_error
{
  my($self) = shift;

  if(@_)
  {
    return $self->{'nice_error'} = shift;
  }

  return $self->{'nice_error'} || $self->{'error'};
}

sub login
{
  my($self, %args) = @_;

  my $session = $self->session or die "Cannot login without session object";

  #
  # Get user object
  #

  my $user = $self->rose_user or return 0;

  unless($user->is_active)
  {
    $self->error('Account is inactive.');
    return 0;
  }

  unless($session->login($user))
  {
    $self->error($session->error);
    return 0;
  }

  #
  # Set authentication credentials
  #

  my $auth = $self->create_auth_credentials($self) or return 0;
  $Debug && warn "Setting user auth: ", $auth, "\n";
  $self->auth_credentials($auth);

  $self->rose_user_type($user->type);

  #
  # Set group membership
  #

  $self->reload_group_membership or warn $self->error;

  #
  # Set logged in flag
  #

  #$Debug && warn "$self set logged_in = 1\n";
  $self->is_anonymous(0);
  $self->login_expired(0);
  $self->logged_in(1);

  no strict 'refs';

  if(!$args{'delay_session_store'}) # && (ref $self eq __PACKAGE__ || !defined &{ref($self) . '::login'}))
  {
    #$Debug && warn __PACKAGE__, " store session\n";
    # Store is a destructive operation (because it unties the session data hash),
    # so we must reload the session if we want to keep it around (and we do).
    $session->store or warn "Could not store session: ", $session->error;
    $session->load  or warn "Could not reload session: ", $session->error;
  }

  return 1;
}

sub logout
{
  my($self) = shift;

  $self->auth_credentials(undef);

  $self->password(undef);
  $self->logged_in(0);
  $self->is_anonymous(1);

  if(my $session = $self->session)
  {
    return $session->logout(@_);
  }

  return;
}

sub is_logged_in
{
  my($self) = shift;

  $self->check_auth_credentials($self) or return 0;

  my $current_time    = time;
  my $login_time      = $self->login_time;
  my $login_duration  = $self->login_duration;

  if($login_time && $login_duration)
  {
    $Debug && warn "$self check login expiration $current_time - $login_time <= $login_duration\n",
                   ($current_time - $login_time), " <= $login_duration\n";

    if($current_time - $login_time <= $login_duration)
    {
      if($self->logged_in)
      {
        # Conditionally update login time 
        if(LOGIN_REFRESH && $current_time != $login_time && 
           $login_duration / ($current_time - $login_time) < LOGIN_REFRESH)
        {
          $Debug && warn "$self updating login time.\n";
          $self->login_time(time);
        }

        my $groups_load_time = $self->group_membership_load_time;

        # Conditionally update group membership
        if(USER_GROUPS_REFRESH && 
           $current_time > ($groups_load_time + USER_GROUPS_REFRESH))
        {
          $self->reload_group_membership;
        }

        return $self->logged_in(1);
      }
    }
    else
    {
      #$Debug && warn "Login expired!\n"
      $self->login_expired(1);
    }
  }

  $self->password(undef);
  $self->password_encrypted(undef);

  return 0;
}

sub create_auth_credentials
{
  my($self) = shift;

  my $auth = Rose::WebSite::User::Auth->create_auth_credentials(@_);

  unless($auth)
  {
    $self->error(Rose::WebSite::User::Auth->error);
    return 0;
  }

  return $auth;
}

sub check_auth_credentials
{
  my($self) = shift;

  unless(Rose::WebSite::User::Auth->check_auth_credentials(@_))
  {
    $self->error(Rose::WebSite::User::Auth->error);
    return 0;
  }

  return 1;
}

sub session_scratch
{
  my($self)   = shift;
  my($param)  = shift;

  my $prefix = (caller)[0] . '-';

  if(@_)
  {
    my $val = shift;

    if(my $session = $self->session)
    {
      $self->{$param} = $session->scratch_pad($prefix . $param => $val)
    }

    return $self->{$param} = $val;
  }

  if(my $session = $self->session)
  {
    return $self->{$param} = $session->scratch_pad($prefix . $param);
  }

  return $self->{$param};
}

sub session_data
{
  my($self)   = shift;
  my($param)  = shift;

  if(@_)
  {
    if(my $session = $self->session)
    {
      return $session->$param(shift);
    }

    return $self->{$param} = shift;
  }

  if(my $session = $self->{'session'})
  {
    return $session->$param();
  }

  return $self->{$param};
}

sub is_anonymous     { shift->session_data('is_anonymous', @_) }
sub user_id          { shift->session_data('user_id', @_) }
sub id               { shift->user_id(@_) }
sub username         { shift->session_data('username', @_) }
sub password         { shift->session_data('password', @_) }
sub password_encrypted { shift->session_data('password_encrypted', @_) }
sub email            { shift->session_data('email', @_) }
sub first_name       { shift->session_data('first_name', @_) }
sub auth_credentials { shift->session_data('auth_credentials', @_) }
sub last_name        { shift->session_data('last_name', @_) }

sub rose_user_type    { shift->session_data('rose_user_type', @_) }

sub logged_in        { shift->session_data('logged_in', @_) }
sub login_time       { shift->session_data('login_time', @_) }
sub login_duration   { shift->session_data('login_duration', @_) }
sub login_expired    { shift->session_data('login_expired', @_) }

sub login_is_expired { shift->session->login_is_expired }

sub is_admin { $_[0]->rose_user_type eq 'admin' }

sub name
{
  my($self) = shift;

  my $name = join(' ', grep(/\S/, $self->first_name, $self->last_name));

  $name ||= $self->username;

  return $name;
}

sub rose_user
{
  my($self, %args) = @_;

  return $self->{'rose_user'} = $_[1]  if(@_ == 2);
  return $self->{'rose_user'}  if($self->{'rose_user'});

  my $username = $self->username;
  my $password = $self->password;

  return undef  unless($username =~ /\S/);

  $password = ''  unless(defined $password);

  if($self->is_logged_in && !$password)
  {
    $args{'no_auth'} = 1;
  }

  if(FAKE_AUTH)
  {
    return $self->{'rose_user'} =
      $self->_create_fake_rose_user(username => $username,
                                   password => $password,
                                   %args);
  }

  my $user = $self->_create_rose_user(username => $username,
                                     password => $password,
                                     %args);

  unless($user)
  {
    if(Rose::Users->error)
    {
      $self->error("Could not lookup user $username:$password - " . Rose::Users->error);
      $self->nice_error("Could not lookup user '$username' due to an error.");
    }
    else
    {
      $self->error("No such user - $username:$password");
      $self->nice_error("Invalid username or password.");
    }

    return undef;
  }

  $self->is_anonymous(0);

  return $self->{'rose_user'} = $user;
}

sub _create_fake_rose_user
{
  my($self, %args) = @_;

  return
    Rose::User->new(
      username   => $args{'username'},
      password   => $args{'password'},
      user_id    => -1,
      email      => 'anonymous@anonymous.com',
      first_name => 'John',
      last_name  => 'Doe');
}

sub _create_rose_user
{
  my($self, %args) = @_;

  my $user;

  if($args{'no_auth'})
  {
    $user = Rose::Users->get_user(username => $args{'username'},
                                 status   => 'active');
  }
  else
  {
    $user =
      Rose::Users->get_user(username => { field => 'lower(username)',
                                        'eq'   => lc $args{'username'} },
                           password => $args{'password'},
                           status   => 'active');
  }

  return $user;
}

sub sync_with_rose_user
{
  my($self) = shift;

  my $rose_user = shift || $self->rose_user;

  foreach my $field (qw(username first_name last_name email))
  {
    #$Debug && warn "$self->$field(", $rose_user->$field(), ")\n";
    $self->$field($rose_user->$field());
  }

  if(defined $rose_user->password)
  {
    $self->password($rose_user->password);
  }

  my $auth = $self->create_auth_credentials($self) or return 0;
  $Debug && warn "Setting user auth: ", $auth, "\n";
  $self->auth_credentials($auth);

  return 1;
}

sub preference_is_valid { exists $CONF{'VALID_PREFERENCES'}{$_[1]} }

sub reload_group_membership
{
  return 1;
#   my($self) = shift;
#   #$Debug && warn "reload_group_membership() - ", join(':', (caller)[0,2]), "\n";
#   $Debug && warn "$self reloading group membership.\n";
# 
#   my $groups = 
#     Rose::WebSite::User::Groups->get_user_groups(
#       singlepoint_id => $self->singlepoint_id->id,
#       username       => $self->username);
# 
#   if($groups)
#   {
#     my(%session_scratch, %in_object);
# 
#     foreach my $group (@$groups)
#     {
#       $session_scratch{$group->id} =
#       {
#         name        => $group->name,
#         description => $group->description,
#       };
# 
#       $in_object{$group->id} = $group;
# 
#       $Debug && warn "Group ", $group->id, " - ", 
#                      $group->name, ':', $group->description, "\n";
#     }
# 
#     $self->session_scratch('group_membership' => \%session_scratch);
# 
#     $self->{'_group_membership'} = \%in_object;
# 
#     $self->group_membership_load_time(time);
# 
#     return 1;
#   }
# 
#   $self->error("Could not get group membership: " .
#                Rose::WebSite::User::Groups->error);
# 
#   warn $self->error;
# 
#   $self->nice_error("Could not get get group membership.");
# 
#   return;
}

sub group_membership_load_time
{
  shift->session_data('group_membership_load_time', @_);
}

sub groups
{
  return (wantarray) ? () : [];
#   my($self) = shift;
# 
#   unless(defined $self->{'_group_membership'})
#   {
#     $self->reload_group_membership or return;
#   }
# 
#   my @groups = sort { $a->name cmp $b->name }
#                values %{$self->{'_group_membership'}};
# 
#   return (wantarray) ? @groups : \@groups;
}

sub group_ids
{
  return (wantarray) ? () : [];
#   my($self) = shift;
# 
#   unless(defined $self->{'_group_membership'})
#   {
#     $self->reload_group_membership or return;
#   }
# 
#   my @group_ids = map { $_->id } sort { $a->name cmp $b->name }
#                values %{$self->{'_group_membership'}};
# 
#   return (wantarray) ? @group_ids : \@group_ids;
}

sub is_a_member_of_group
{
  return 0;
#   my($self, %args) = @_;
# 
#   unless(defined $self->{'_group_membership'})
#   {
#     $self->reload_group_membership or return;
#   }
# 
#   croak 'is_a_member_of_group() requires a numeric group id'
#     unless(@_);
# 
#   my $group_id;
# 
#   if(@_ == 1)
#   {
#     $group_id = $_[1];
# 
#     if(ref $group_id && $group_id->isa('Rose::WebSite::User::Group'))
#     {
#       $group_id = $group_id->id;
#     }
#   }
# 
#   unless(defined $group_id)
#   {
#     if(exists $args{'group_id'})
#     {
#       $group_id = $args{'group_id'};
#     }
#     elsif(exists $args{'group'})
#     {
#       $group_id = $args{'group'}->id;
#     }
#   }
# 
#   unless($group_id =~ /^\d+$/)
#   {
#     croak 'is_a_member_of_group() requires a numeric group id';
#   }
# 
#   return $self->{'_group_membership'}{$group_id}
#     if(exists $self->{'_group_membership'}{$group_id});
# 
#   return 0;
}

1;
