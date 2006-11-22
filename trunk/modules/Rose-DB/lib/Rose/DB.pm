package Rose::DB;

use strict;

use DBI;
use Carp();
use Bit::Vector::Overload;
use SQL::ReservedWords();

use Time::Clock;
use Rose::DateTime::Util();

use Rose::DB::Registry;
use Rose::DB::Registry::Entry;
use Rose::DB::Constants qw(IN_TRANSACTION);

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Error;

our $VERSION = '0.731';

our $Debug = 0;

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'default_domain',
    'default_type',
    'registry',
    'max_array_characters',
    'max_interval_characters',
  ]
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    driver_classes      => { interface => 'get_set_all' },
    _driver_class       => { interface => 'get_set', hash_key => 'driver_classes' },
    delete_driver_class => { interface => 'delete', hash_key => 'driver_classes' },

    default_connect_options => { interface => 'get_set_all',  },
    default_connect_option  => { interface => 'get_set', hash_key => 'default_connect_options' },
    delete_connect_option   => { interface => 'delete', hash_key => 'default_connect_options' },
  ],
);

__PACKAGE__->default_domain('default');
__PACKAGE__->default_type('default');

__PACKAGE__->max_array_characters(255);    # Used for array type emulation
__PACKAGE__->max_interval_characters(255); # Used for interval type emulation

__PACKAGE__->driver_classes
(
  mysql    => 'Rose::DB::MySQL',
  pg       => 'Rose::DB::Pg',
  informix => 'Rose::DB::Informix',
  oracle   => 'Rose::DB::Oracle',
  sqlite   => 'Rose::DB::SQLite',
  generic  => 'Rose::DB::Generic',
);

__PACKAGE__->default_connect_options
(
  AutoCommit => 1,
  RaiseError => 1,
  PrintError => 1,
  ChopBlanks => 1,
  Warn       => 0,
);

BEGIN { __PACKAGE__->registry(Rose::DB::Registry->new(parent => __PACKAGE__)) }

my %Class_Loaded;

# Load on demand instead
# LOAD_SUBCLASSES:
# {
#   my %seen;
# 
#   my $map = __PACKAGE__->driver_classes;
# 
#   foreach my $class (values %$map)
#   {
#     eval qq(require $class)  unless($seen{$class}++);
#     die "Could not load $class - $@"  if($@);
#   }
# }

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'scalar' =>
  [
    qw(database dbi_driver schema catalog host port username 
       _dbh_refcount id)
  ],

  'boolean' =>
  [
    'auto_create'    => { default => 1 },
    'european_dates' => { default => 0 },
  ],

  'scalar --get_set_init' =>
  [
    'domain',
    'type',
    'date_handler',
    'server_time_zone',
    #'class',
  ],

  'array' => 
  [
    'post_connect_sql',
    'pre_disconnect_sql',
  ],

  'hash' =>
  [
    connect_options => { interface => 'get_set_init' },
  ]
);

#
# Class methods
#

sub register_db
{
  my $class = shift;

  # Smuggle parent/caller in with an otherwise nonsensical arrayref arg
  my $entry = $class->registry->add_entry([ $class ], @_);

  if($entry)
  {
    my $driver = $entry->driver;

    Carp::confess "No driver found for registry entry $entry"
      unless(defined $driver);

    $class->setup_dynamic_class_for_driver($driver);
  }

  return $entry;
}

our %Rebless;

sub setup_dynamic_class_for_driver
{
  my($class, $driver) = @_;

  my $driver_class = $class->driver_class($driver) ||
     $class->driver_class('generic') || Carp::croak
    "No driver class found for drivers '$driver' or 'generic'";

  unless($Rebless{$class,$driver_class})
  {
    no strict 'refs';
    unless($Class_Loaded{$driver_class} || @{"${driver_class}::ISA"})
    {
      eval "require $driver_class";
      Carp::croak "Could not load driver class '$driver_class' - $@"  if($@);
    }

    $Class_Loaded{$driver_class}++;

    # Make a new driver class based on the current class
    my $new_class = $class . '::__RoseDBPrivate__::' . $driver_class;

    no strict 'refs';        
    @{"${new_class}::ISA"} = ($driver_class, $class);
    *{"${new_class}::STORABLE_thaw"}   = \&STORABLE_thaw;
    *{"${new_class}::STORABLE_freeze"} = \&STORABLE_freeze;

    # Cache result
    $Rebless{$class,$driver_class} = $new_class;
  }

  return $Rebless{$class,$driver_class};
}

sub unregister_db { shift->registry->delete_entry(@_) }

sub default_implicit_schema { undef }

sub use_private_registry { $_[0]->registry(Rose::DB::Registry->new(parent => $_[0])) }

sub modify_db
{
  my($class, %args) = @_;

  my $domain = delete $args{'domain'} || $class->default_domain ||
    Carp::croak "Missing domain";

  my $type   = delete $args{'type'} || $class->default_type ||
    Carp::croak "Missing type";

  my $entry = $class->registry->entry(domain => $domain, type => $type) or
    Carp::croak "No db defined for domain '$domain' and type '$type'";

  while(my($key, $val) = each(%args))
  {
    $entry->$key($val);
  }

  return $entry;
}

sub db_exists
{
  my($class) = shift;

  my %args = (@_ == 1) ? (type => $_[0]) : @_;

  my $domain = $args{'domain'} || $class->default_domain ||
    Carp::croak "Missing domain";

  my $type   = $args{'type'} || $class->default_type ||
    Carp::croak "Missing type";

  return $class->registry->entry_exists(domain => $domain, type => $type);
}

sub alias_db
{
  my($class, %args) = @_;

  my $source = $args{'source'} or Carp::croak "Missing source";

  my $src_domain = $source->{'domain'} or Carp::croak "Missing source domain";
  my $src_type   = $source->{'type'} or Carp::croak "Missing source type";

  my $alias = $args{'alias'} or Carp::croak "Missing alias";

  my $alias_domain = $alias->{'domain'} or Carp::croak "Missing source domain";
  my $alias_type   = $alias->{'type'} or Carp::croak "Missing source type";

  my $registry = $class->registry;

  my $entry = $registry->entry(domain => $src_domain, type => $src_type) or
    Carp::croak "No db defined for domain '$src_domain' and type '$src_type'";

  $registry->add_entry(domain => $alias_domain, 
                       type   => $alias_type,
                       entry  => $entry);
}

sub unregister_domain { shift->registry->delete_domain(@_) }

sub driver_class
{
  my($class, $driver) = (shift, lc shift);

  if(@_)
  {
    $class->_driver_class($driver, @_);
    $class->setup_dynamic_class_for_driver($driver);
  }

  return $class->_driver_class($driver);
}

#
# Object methods
#

sub new
{
  my($class) = shift;

  @_ = (type => $_[0])  if(@_ == 1);

  my %args = @_;

  my $domain = 
    exists $args{'domain'} ? $args{'domain'} : $class->default_domain;

  my $type = 
    exists $args{'type'} ? $args{'type'} : $class->default_type;

  my $db_info;

  # I'm being bad here for speed purposes, digging into private hashes instead
  # of using object methods.  I'll fix it when the first person emails me to
  # complain that I'm breaking their Rose::DB or Rose::DB::Registry[::Entry]
  # subclass by doing this.  Call it "demand-paged programming" :)
  my $registry = $class->registry->hash;

  if(exists $registry->{$domain} && exists $registry->{$domain}{$type})
  {
    $db_info = $registry->{$domain}{$type}
  }
  else
  {
    Carp::croak "No database information found for domain '$domain' and type '$type'";
  }

  my $driver = $db_info->{'driver'}; 

  Carp::croak "No driver found for domain '$domain' and type '$type'"
    unless(defined $driver);

  my $driver_class = $class->driver_class($driver) ||
     $class->driver_class('generic') || Carp::croak
    "No driver class found for drivers '$driver' or 'generic'";

  unless($Class_Loaded{$driver_class})
  {
    $class->load_driver_class($driver_class);
  }

  my $self;

  REBLESS: # Do slightly evil re-blessing magic
  {
    # Check cache
    if(my $new_class = $Rebless{$class,$driver_class})
    {
      $self = bless {}, $new_class;
    }
    else
    {
      # Make a new driver class based on the current class
      my $new_class = $class . '::__RoseDBPrivate__::' . $driver_class;

      no strict 'refs';        
      @{"${new_class}::ISA"} = ($driver_class, $class);

      $self = bless {}, $new_class;

      # Cache result
      $Rebless{$class,$driver_class} = ref $self;
    }
  }

  $self->class($class);
  $self->{'id'} = "$domain\0$type";

  $self->init(@_);

  return $self;
}

sub class 
{
  my($self) = shift;
  return $self->{'_origin_class'} = shift  if(@_);
  return $self->{'_origin_class'} || ref $self;
}

sub init
{
  my($self) = shift;
  $self->SUPER::init(@_);
  $self->init_db_info;
}

sub load_driver_class
{
  my($class, $arg) = @_;

  my $driver_class = $class->driver_class($arg) || $arg;

  no strict 'refs';
  unless(defined ${"${driver_class}::VERSION"})
  {
    eval "require $driver_class";
    Carp::croak "Could not load driver class '$driver_class' - $@"  if($@);
  }

  $Class_Loaded{$driver_class}++;
}

sub driver_class_is_loaded { $Class_Loaded{$_[1]} }

sub load_driver_classes
{
  my($class) = shift;

  my $map = $class->driver_classes;

  foreach my $arg (@_ ? @_ : keys %$map)
  {
    $class->load_driver_class($arg);
  }

  return;
}

sub database_version
{
  my($self) = shift;
  return $self->{'database_version'}  if(defined $self->{'database_version'});
  return $self->{'database_version'} = $self->dbh->get_info(18); # SQL_DBMS_VER
}

# Use a closure to keep the password from appearing when the
# object is dumped using Data::Dumper
sub password
{
  my($self) = shift;

  if(@_)
  {
    my $password = shift;
    $self->{'password_closure'} = sub { $password };
    return $password;
  }

  return $self->{'password_closure'} ? $self->{'password_closure'}->() : undef;
}

# These have to "cheat" to get the right values by going through
# the real origin class because they may be called after the 
# re-blessing magic takes place.
sub init_domain { shift->{'_origin_class'}->default_domain }
sub init_type   { shift->{'_origin_class'}->default_type }

sub init_date_handler { Rose::DateTime::Format::Generic->new }
sub init_server_time_zone { 'floating' }

sub init_db_info
{
  my($self) = shift;

  my $class = ref $self;

  my $domain = $self->domain;
  my $type   = $self->type;

  my $db_info;

  # I'm being bad here for speed purposes, digging into private hashes instead
  # of using object methods.  I'll fix it when the first person emails me to
  # complain that I'm breaking their Rose::DB or Rose::DB::Registry[::Entry]
  # subclass by doing this.  Call it "demand-paged programming" :)
  my $registry = $self->class->registry->hash;

  if(exists $registry->{$domain} && exists $registry->{$domain}{$type})
  {
    $db_info = $registry->{$domain}{$type}
  }
  else
  {
    Carp::croak "No database information found for domain '$domain' and type '$type'";
  }

  unless($self->{'connect_options_for'}{$domain} && 
         $self->{'connect_options_for'}{$domain}{$type})
  {
    $self->{'connect_options'} = undef;

    if(my $custom_options = $db_info->{'connect_options'})
    {
      my $options = $self->connect_options;
      @$options{keys %$custom_options} = values %$custom_options;
    }

    $self->{'connect_options_for'} = { $domain => { $type => 1 } };
  }

  $self->driver($db_info->{'driver'});

  my $dsn = $db_info->{'dsn'} ||= $self->build_dsn(domain => $domain, 
                                                   type   => $type,
                                                   %$db_info);

  while(my($field, $value) = each(%$db_info))
  {
    next  if($field eq 'connect_options');
    $self->$field($value);
  }

  return 1;
}

sub init_connect_options
{
  my($class) = ref $_[0];
  $class->default_connect_options;
}

sub connect_option
{
  my($self, $param) = (shift, shift);

  my $options = $self->connect_options;

  return $options->{$param} = shift  if(@_);
  return $options->{$param};
}

sub dsn
{
  my($self) = shift;

  return $self->{'dsn'}  unless(@_);

  $self->{'dsn'} = shift;

  if(DBI->can('parse_dsn'))
  {
    if(my($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) =
         DBI->parse_dsn($self->{'dsn'}))
    {
      $self->driver($driver)  if($driver);

      if($attr_string)
      {
        $self->_parsed_dsn($attr_hash, $driver_dsn);
      }
    }
    else { $self->error("Couldn't parse DSN '$self->{'dsn'}'") }
  }

  return $self->{'dsn'};
}

sub database_from_dsn
{
  my($self_or_class, $dsn) = @_;

  my($scheme, $driver, $attr_string, $attr_hash, $driver_dsn);

  # x DBI->parse_dsn('dbi:mysql:database=test;host=localhost')
  # 0  'dbi'
  # 1  'mysql'
  # 2  undef
  # 3  undef
  # 4  'database=test;host=localhost'

  if(DBI->can('parse_dsn'))
  {
    ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) = 
      DBI->parse_dsn($dsn);
  }

  my $db = $attr_hash->{'dbname'} || $attr_hash->{'database'};

  unless($db)
  {
    # Wing it...
    unless($attr_string ||= $driver_dsn)
    {
      ($attr_string = $dsn) =~ s/^dbi:\w+://i;
    }

    $attr_string =~ /(?:dbname|database)=([^; ]+)|^([^; ]+)/i;

    $db = $1 || $2;
  }

  return $db;
}

sub _parsed_dsn { }

sub dbh
{
  my($self) = shift;

  return $self->{'dbh'} || $self->init_dbh  unless(@_);

  unless(defined($_[0]))
  {
    return $self->{'dbh'} = undef;
  }

  $self->driver($_[0]->{'Driver'}{'Name'});

  return $self->{'dbh'} = $_[0];
}

sub driver
{
  if(@_ > 1)
  {
    $_[1] = lc $_[1];

    if(defined $_[1] && defined $_[0]->{'driver'} && $_[0]->{'driver'} ne $_[1])
    {
      Carp::croak "Attempt to change driver from '$_[0]->{'driver'}' to ",
                  "'$_[1]' detected.  The driver cannot be changed after ",
                  "object creation.";
    }

    return $_[0]->{'driver'} = $_[1];
  }

  return $_[0]->{'driver'};
}

sub retain_dbh
{
  my($self) = shift;
  my $dbh = $self->dbh or return undef;
  #$Debug && warn "$self->{'_dbh_refcount'} -> ", ($self->{'_dbh_refcount'} + 1), " $dbh\n";
  $self->{'_dbh_refcount'}++;
  return $dbh;
}

sub release_dbh
{
  my($self, %args) = @_;

  my $dbh = $self->{'dbh'} or return 0;

  if($args{'force'})
  {
    $self->{'_dbh_refcount'} = 0;

    # Account for possible Apache::DBI magic
    if(UNIVERSAL::isa($dbh, 'Apache::DBI::db'))
    {
      return $dbh->DBI::db::disconnect; # bypass Apache::DBI
    }
    else
    {
      return $dbh->disconnect;
    }
  }

  #$Debug && warn "$self->{'_dbh_refcount'} -> ", ($self->{'_dbh_refcount'} - 1), " $dbh\n";
  $self->{'_dbh_refcount'}--;

  unless($self->{'_dbh_refcount'})
  {
    if(my $sqls = $self->pre_disconnect_sql)
    {
      eval
      {
        foreach my $sql (@$sqls)
        {
          $dbh->do($sql) or die "$sql - " . $dbh->errstr;
          return undef;
        }
      };

      if($@)
      {
        $self->error("Could not do pre-disconnect SQL: $@");
        return undef;
      }
    }

    #$Debug && warn "DISCONNECT $dbh ", join(':', (caller(3))[0,2]), "\n";
    return $dbh->disconnect;
  }
  #else { $Debug && warn "DISCONNECT NOOP $dbh ", join(':', (caller(2))[0,2]), "\n"; }

  return 1;
}

use constant DID_PCSQL_KEY => 'private_rose_db_did_post_connect_sql';

sub has_dbh { defined shift->{'dbh'} }

sub init_dbh
{
  my($self) = shift;

  $self->init_db_info;

  my $options = $self->connect_options;

  $Debug && warn "DBI->connect('", $self->dsn, "', '", $self->username, "', ...)\n";

  $self->{'error'} = undef;
  $self->{'database_version'} = undef;

  my $dbh = DBI->connect($self->dsn, $self->username, $self->password, $options);

  unless($dbh)
  {
    $self->error("Could not connect to database: $DBI::errstr");
    return 0;
  }

  $self->{'_dbh_refcount'}++;
  #$Debug && warn "CONNECT $dbh ", join(':', (caller(3))[0,2]), "\n";

  #$self->_update_driver;

  if((my $sqls = $self->post_connect_sql) && !$dbh->{DID_PCSQL_KEY()})
  {
    eval
    {
      foreach my $sql (@$sqls)
      {
        #$Debug && warn "$dbh DO: $sql\n";
        $dbh->do($sql) or die "$sql - " . $dbh->errstr;
      }
    };

    if($@)
    {
      $self->error("Could not do post-connect SQL: $@");
      $dbh->disconnect;
      return undef;
    }

    $dbh->{DID_PCSQL_KEY()} = 1;
  }

  return $self->{'dbh'} = $dbh;
}

sub print_error { shift->_dbh_and_connect_option('PrintError', @_) }
sub raise_error { shift->_dbh_and_connect_option('RaiseError', @_) }
sub autocommit  { shift->_dbh_and_connect_option('AutoCommit', @_) }

sub _dbh_and_connect_option
{
  my($self, $param) = (shift, shift);

  if(@_)
  {
    my $val = $_[0] ? 1 : 0;
    $self->connect_option($param => $val);

    $self->{'dbh'}{$param} = $val  if($self->{'dbh'});
  }

  return $self->{'dbh'} ? $self->{'dbh'}{$param} : 
         $self->connect_option($param);
}

sub connect
{
  my($self) = shift;

  $self->dbh or return 0;
  return 1;
}

sub disconnect
{
  my($self) = shift;

  $self->release_dbh(@_) or return undef;

  $self->{'dbh'} = undef;
}

sub begin_work
{
  my($self) = shift;

  my $dbh = $self->dbh or return undef;

  if($dbh->{'AutoCommit'})
  {
    my $ret;

    #$Debug && warn "BEGIN TRX\n";

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      $ret = $dbh->begin_work
    };

    if($@)
    {
      $self->error('begin_work() - ' . $dbh->errstr);
      return undef;
    }

    unless($ret)
    {
      $self->error('begin_work() failed - ' . $dbh->errstr);
      return undef;
    }

    return 1;
  }

  return IN_TRANSACTION;
}

sub commit
{
  my($self) = shift;

  return 0  unless(defined $self->{'dbh'} && $self->{'dbh'}{'Active'});

  my $dbh = $self->dbh or return undef;

  unless($dbh->{'AutoCommit'})
  {
    my $ret;

    #$Debug && warn "COMMIT TRX\n";    

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      $ret = $dbh->commit;
    };

    if($@)
    {
      $self->error('commit() - ' . $dbh->errstr);
      return undef;
    }

    unless($ret)
    {
      $self->error('Could not commit transaction: ' . 
                   ($dbh->errstr || $DBI::errstr || 
                    'Possibly a referential integrity violation.  ' .
                    'Check the database error log for more information.'));
      return undef;
    }

    return 1;
  }

  return -1;
}

sub rollback
{
  my($self) = shift;

  return 0  unless(defined $self->{'dbh'} && $self->{'dbh'}{'Active'});

  my $dbh = $self->dbh or return undef;

  my $ac = $dbh->{'AutoCommit'};

  my $ret;

  #$Debug && warn "ROLLBACK TRX\n";

  eval
  {
    local $dbh->{'RaiseError'} = 1;
    $ret = $dbh->rollback;
  };

  if($@)
  {
    $self->error('rollback() - ' . $dbh->errstr);
    return undef;
  }

  unless($ret || $ac)
  {
    $self->error('rollback() failed - ' . $dbh->errstr);
    return undef;
  }

  # DBI does this for me...
  #$dbh->{'AutoCommit'} = 1;

  return 1;
}

sub do_transaction
{
  my($self, $code) = (shift, shift);

  my $dbh = $self->dbh or return undef;  

  eval
  {
    local $dbh->{'RaiseError'} = 1;
    $self->begin_work or die $self->error;
    $code->(@_);
    $self->commit or die $self->error;
  };

  if($@)
  {
    my $error = "do_transaction() failed - $@";

    if($self->rollback)
    {
      $self->error($error);
    }
    else
    {
      $self->error("$error.  rollback() also failed - " . $self->error)
    }

    return undef;
  }

  return 1;
}

sub auto_quote_table_name
{
  my($self, $name) = @_;

  if($name =~ /\W/ || $self->is_reserved_word($name))
  {
    return $self->quote_table_name($name, @_);
  }

  return $name;
}

sub auto_quote_column_name
{
  my($self, $name) = @_;

  if($name =~ /\W/ || $self->is_reserved_word($name))
  {
    return $self->quote_column_name($name, @_);
  }

  return $name;
}

sub quote_column_name 
{
  my $name = $_[1];
  $name =~ s/"/""/g;
  return qq("$name");
}

sub quote_table_name
{
  my $name = $_[1];
  $name =~ s/"/""/g;
  return qq("$name");
}

sub unquote_column_name
{
  my($self_or_class, $name) = @_;

  # handle quoted strings with quotes doubled inside them
  if($name =~ /^(['"`])(.+)\1$/)
  {
    my $q = $1;
    $name = $2;
    $name =~ s/$q$q/$q/g;
  }

  return $name;
}

*unquote_table_name = \&unquote_column_name;

#sub is_reserved_word { 0 }

*is_reserved_word = \&SQL::ReservedWords::is_reserved;

BEGIN
{
  sub quote_identifier_dbi
  {
    my($self) = shift;
    my $dbh = $self->dbh or die $self->error;
    return $dbh->quote_identifier(@_);
  }

  sub quote_identifier_fallback
  {
    my($self, $catalog, $schema, $table) = @_;
    return join('.', map { qq("$_") } grep { defined } ($schema, $table));
  }

  if($DBI::VERSION >= 1.21)
  {
    *quote_identifier = \&quote_identifier_dbi;
  }
  else
  {
    *quote_identifier = \&quote_identifier_fallback;
  }
}

sub quote_column_with_table 
{
  my($self, $column, $table) = @_;

  return $table ?
         $self->quote_table_name($table) . '.' .
         $self->quote_column_name($column) :
         $self->quote_column_name($column);
}

sub auto_quote_column_with_table 
{
  my($self, $column, $table) = @_;

  return $table ?
         $self->auto_quote_table_name($table) . '.' .
         $self->auto_quote_column_name($column) :
         $self->auto_quote_column_name($column);
}

sub has_primary_key
{
  my($self) = shift;
  my $columns = $self->primary_key_column_names(@_);
  return (ref $columns && @$columns) ? 1 : 0;
}

sub primary_key_column_names
{
  my($self) = shift;

  my %args = @_ == 1 ? (table => @_) : @_;

  my $table   = $args{'table'} or Carp::croak "Missing table name parameter";
  my $catalog = $args{'catalog'} || $self->catalog;
  my $schema  = $args{'schema'}  || $self->schema;

  $schema = $self->default_implicit_schema  unless(defined $schema);

  $table = lc $table  if($self->likes_lowercase_table_names);

  $schema = lc $schema   
    if(defined $schema && $self->likes_lowercase_schema_names);

  $catalog = lc $catalog
    if(defined $catalog && $self->likes_lowercase_catalog_names);

  my $table_unquoted = $self->unquote_table_name($table);

  my $columns;

  eval 
  {
    $columns = 
      $self->_get_primary_key_column_names($catalog, $schema, $table_unquoted);
  };

  if($@ || !$columns)
  {
    no warnings 'uninitialized'; # undef strings okay
    $@ = 'no primary key columns found'  unless(defined $@);
    Carp::croak "Could not get primary key columns for catalog '" . 
                $catalog . "' schema '" . $schema . "' table '" . 
                $table_unquoted . "' - " . $@;
  }

  return wantarray ? @$columns : $columns;
}

sub _get_primary_key_column_names
{
  my($self, $catalog, $schema, $table) = @_;

  my $dbh = $self->dbh or die $self->error;

  local $dbh->{'FetchHashKeyName'} = 'NAME';

  my $sth = $dbh->primary_key_info($catalog, $schema, $table);

  unless(defined $sth)
  {
    no warnings 'uninitialized'; # undef strings okay
    $self->error("No primary key information found for catalog '", $catalog,
                 "' schema '", $schema, "' table '", $table, "'");
    return [];
  }

  my @columns;

  PK: while(my $pk_info = $sth->fetchrow_hashref)
  {
    CHECK_TABLE: # Make sure this column is from the right table
    {
      no warnings; # Allow undef coercion to empty string

      $pk_info->{'TABLE_NAME'} = 
        $self->unquote_table_name($pk_info->{'TABLE_NAME'});

      next PK  unless($pk_info->{'TABLE_CAT'}   eq $catalog &&
                      $pk_info->{'TABLE_SCHEM'} eq $schema &&
                      $pk_info->{'TABLE_NAME'}  eq $table);
    }

    unless(defined $pk_info->{'COLUMN_NAME'})
    {
      Carp::croak "Could not extract column name from DBI primary_key_info()";
    }

    push(@columns, $pk_info->{'COLUMN_NAME'});
  }

  return \@columns;
}

#
# These methods could/should be overriden in driver-specific subclasses
#

sub insertid_param { undef }
sub null_date      { '0000-00-00'  }
sub null_datetime  { '0000-00-00 00:00:00' }
sub null_timestamp { '00000000000000' }
sub min_timestamp  { '00000000000000' }
sub max_timestamp  { '00000000000000' }

sub last_insertid_from_sth { $_[1]->{$_[0]->insertid_param} }
sub generate_primary_key_values       { (undef) x ($_[1] || 1) }
sub generate_primary_key_placeholders { (undef) x ($_[1] || 1) }

# Boolean formatting and parsing

sub format_boolean { $_[1] ? 1 : 0 }

sub parse_boolean
{
  my($self, $value) = @_;
  return $value  if($self->validate_boolean_keyword($_[1]) || $_[1] =~ /^\w+\(.*\)$/);
  return 1  if($value =~ /^(?:t(?:rue)?|y(?:es)?|1)$/);
  return 0  if($value =~ /^(?:f(?:alse)?|no?|0)$/);

  $self->error("Invalid boolean value: '$value'");
  return undef;
}

# Date formatting

sub format_date
{
  my($self, $date) = @_;
  return $date  if($self->validate_date_keyword($date) || $date =~ /^\w+\(.*\)$/);
  return $self->date_handler->format_date($date);
}

sub format_datetime
{
  my($self, $date) = @_;
  return $date  if($self->validate_datetime_keyword($date) || $date =~ /^\w+\(.*\)$/);
  return $self->date_handler->format_datetime($date);
}

use constant HHMMSS_PRECISION => 6;
use constant HHMM_PRECISION   => 4;

sub format_time
{
  my($self, $time, $precision) = @_;
  return $time  if($self->validate_time_keyword($time) || $time =~ /^\w+\(.*\)$/);

  if(defined $precision)
  {
    if($precision > HHMMSS_PRECISION)
    {
      my $scale = $precision - HHMMSS_PRECISION;
      return $time->format("%H:%M:%S%${scale}n");
    }
    elsif($precision == HHMMSS_PRECISION)
    {
      return $time->format("%H:%M:%S");
    }
    elsif($precision == HHMM_PRECISION)
    {
      return $time->format("%H:%M");
    }
  }

  # Punt
  return $time->as_string;
}

sub format_timestamp
{  
  my($self, $date) = @_;
  return $date  if($self->validate_timestamp_keyword($date) || $date =~ /^\w+\(.*\)$/);
  return $self->date_handler->format_timestamp($date);
}

# Date parsing

sub parse_date
{
  my($self, $value) = @_;

  if(UNIVERSAL::isa($value, 'DateTime') || $self->validate_date_keyword($value))
  {
    return $value;
  }

  my $dt;
  eval { $dt = $self->date_handler->parse_date($value) };

  if($@)
  {
    $self->error("Could not parse date '$value' - $@");
    return undef;
  }

  return $dt;
}

sub parse_datetime
{  
  my($self, $value) = @_;

  if(UNIVERSAL::isa($value, 'DateTime') || 
    $self->validate_datetime_keyword($value))
  {
    return $value;
  }

  my $dt;
  eval { $dt = $self->date_handler->parse_datetime($value) };

  if($@)
  {
    $self->error("Could not parse datetime '$value' - $@");
    return undef;
  }

  return $dt;
}

sub parse_timestamp
{  
  my($self, $value) = @_;

  if(UNIVERSAL::isa($value, 'DateTime') || 
    $self->validate_timestamp_keyword($value))
  {
    return $value;
  }

  my $dt;
  eval { $dt = $self->date_handler->parse_timestamp($value) };

  if($@)
  {
    $self->error("Could not parse timestamp '$value' - $@");
    return undef;
  }

  return $dt;
}

sub parse_time
{
  my($self, $value) = @_;

  if(!defined $value || UNIVERSAL::isa($value, 'Time::Clock') || 
     $self->validate_time_keyword($value) || $value =~ /^\w+\(.*\)$/)
  {
    return $value;
  }

  my $time;

  eval 
  {
    $time = Time::Clock->new->parse($value);
  };

  if($@)
  {
    eval
    {
      my $dt = $self->date_handler->parse_time($value);
      # Using parse()/strftime() is faster than using the 
      # Time::Clock constructor and the DateTime accessors.
      $time = Time::Clock->new->parse($dt->strftime('%H:%M:%S.%N'));
    };

    if($@)
    {
      $self->error("Could not parse time '$value' - Time::Clock::parse() failed and $@");
      return undef;
    }
  }

  return $time;
}

sub parse_bitfield
{
  my($self, $val, $size) = @_;

  return undef  unless(defined $val);

  if(ref $val)
  {
    if($size && $val->Size != $size)
    {
      return Bit::Vector->new_Bin($size, $val->to_Bin);
    }

    return $val;
  }

  if($val =~ /^[10]+$/)
  {
    return Bit::Vector->new_Bin($size || length $val, $val);
  }
  elsif($val =~ /^\d*[2-9]\d*$/)
  {
    return Bit::Vector->new_Dec($size || (length($val) * 4), $val);
  }
  elsif($val =~ s/^0x// || $val =~ s/^X'(.*)'$/$1/ || $val =~ /^[0-9a-f]+$/i)
  {
    return Bit::Vector->new_Hex($size || (length($val) * 4), $val);
  }
  elsif($val =~ s/^B'([10]+)'$/$1/i)
  {
    return Bit::Vector->new_Bin($size || length $val, $val);
  }
  else
  {
    $self->error("Could not parse bitfield value '$val'");
    return undef;
    #return Bit::Vector->new_Bin($size || length($val), $val);
  }
}

sub format_bitfield 
{
  my($self, $vec, $size) = @_;

  if($size)
  {
    $vec = Bit::Vector->new_Bin($size, $vec->to_Bin);
    return sprintf('%0*b', $size, hex($vec->to_Hex));
  }

  return sprintf('%b', hex($vec->to_Hex));
}

sub select_bitfield_column_sql { shift->auto_quote_column_with_table(@_) }

sub should_inline_bitfield_values { 0 }

sub parse_array
{
  my($self) = shift;

  return $_[0]  if(ref $_[0]);
  return [ @_ ] if(@_ > 1);

  my $val = $_[0];

  return undef  unless(defined $val);

  $val =~ s/^ (?:\[.+\]=)? \{ (.*) \} $/$1/sx;

  my @array;

  while($val =~ s/(?:"((?:[^"\\]+|\\.)*)"|([^",]+))(?:,|$)//)
  {
    push(@array, (defined $1) ? $1 : $2);
  }

  return \@array;
}

sub format_array
{
  my($self) = shift;

  my @array = (ref $_[0]) ? @{$_[0]} : @_;

  return undef  unless(@array && defined $array[0]);

  my $str = '{' . join(',', map 
  {
    if(/^[-+]?\d+(?:\.\d*)?$/)
    {
      $_
    }
    else
    {
      s/\\/\\\\/g; 
      s/"/\\"/g;
      qq("$_") 
    }
  } @array) . '}';

  if(length($str) > $self->max_array_characters)
  {
    Carp::croak "Array string is longer than ", ref($self), 
                "->max_array_characters (", $self->max_array_characters,
                ") characters long: $str";
  }

  return $str;
}

my $Interval_Regex = qr{
(?:\@\s*)?
(?:
  (?: (?: \s* ([+-]?) (\d+) : ([0-5]?\d)? (?:: ([0-5]?\d (?:\.\d+)? )? )?))  # (sign)hhh:mm:ss
  |
  (?:     \s* ( [+-]? \d+ (?:\.\d+(?=\s+s))? ) \s+      # quantity
    (?:                                              # unit
        (?:\b(dec) (?:ades?\b | s?\b)?\b)            # decades
      | (?:\b(d)   (?:ays?\b)?\b)                    # days
      | (?:\b(y)   (?:ears?\b)?\b)                   # years
      | (?:\b(h)   (?:ours?\b)?\b)                   # hours
      | (?:\b(mon) (?:s\b | ths?\b)?\b)              # months
      | (?:\b(mil) (?:s\b | lenniums?\b)?\b)         # millenniums
      | (?:\b(m)   (?:inutes?\b | ins?\b)?\b)        # minutes
      | (?:\b(s)   (?:ec(?:s | onds?)?)?\b)          # seconds
      | (?:\b(w)   (?:eeks?\b)?\b)                   # weeks
      | (?:\b(c)   (?:ent(?:s | ury | uries)?\b)?\b) # centuries
    )
  )
)
(?: \s+ (ago) \b)?                                   # direction
| (.+)
}ix;

sub parse_interval
{
  my($self, $value, $end_of_month_mode) = @_;

  if(!defined $value || UNIVERSAL::isa($value, 'DateTime::Duration') || 
     $self->validate_interval_keyword($value) || $value =~ /^\w+\(.*\)$/)
  {
    return $value;
  }

  for($value)
  {
    s/\A //;
    s/ \z//;
    s/\s+/ /g;
  }

  my(%units, $is_ago, $sign, $error, $dt_duration);

  my $value_pos;

  while(!$error && $value =~ /$Interval_Regex/go)
  {
    $value_pos = pos($value);

    $is_ago = 1  if($16);

    if($2 || $3 || $4)
    {
      if($sign || defined $units{'hours'} || defined $units{'minutes'} || 
         defined $units{'seconds'})
      {
        $error = 1;
        last;
      }

      $sign = ($1 && $1 eq '-') ? -1 : 1;

      my $secs = $4;

      if(defined $secs && $secs != int($secs))
      {
        my $fsecs = substr($secs, index($secs, '.') + 1);
        $secs = int($secs);

        my $len = length $fsecs;

        if($len < 9)
        {
          $fsecs .= ('0' x (9 - length $fsecs));
        }
        elsif($len > 9)
        {
          $fsecs = substr($fsecs, 0, 9);
        }

        $units{'nanoseconds'} = $sign * $fsecs;
      }

      $units{'hours'}   = $sign * ($2 || 0);
      $units{'minutes'} = $sign * ($3 || 0);
      $units{'seconds'} = $sign * ($secs || 0);
    }
    elsif($6)
    {
      if($units{'decades'}) { $error = 1; last }
      $units{'decades'} = $5;
    }
    elsif(defined $7)
    {
      if($units{'days'}) { $error = 1; last }
      $units{'days'} = $5;
    }
    elsif(defined $8)
    {
      if($units{'years'}) { $error = 1; last }
      $units{'years'} = $5;
    }
    elsif(defined $9)
    {
      if($units{'hours'}) { $error = 1; last }
      $units{'hours'} = $5;
    }
    elsif(defined $10)
    {
      if($units{'months'}) { $error = 1; last }
      $units{'months'} = $5;
    }
    elsif(defined $11)
    {
      if($units{'millenniums'}) { $error = 1; last }
      $units{'millenniums'} = $5;
    }
    elsif(defined $12)
    {
      if($units{'minutes'}) { $error = 1; last }
      $units{'minutes'} = $5;
    }
    elsif(defined $13)
    {
      if($units{'seconds'}) { $error = 1; last }

      my $secs = $5;

      $units{'seconds'} = int($secs);

      if($units{'seconds'} != $secs)
      {
        my $fsecs = substr($secs, index($secs, '.') + 1);

        my $len = length $fsecs;

        if($len < 9)
        {
          $fsecs .= ('0' x (9 - length $fsecs));
        }
        elsif($len > 9)
        {
          $fsecs = substr($fsecs, 0, 9);
        }

        $units{'nanoseconds'} = $fsecs;
      }
    }
    elsif(defined $14)
    {
      if($units{'weeks'}) { $error = 1; last }
      $units{'weeks'} = $5;
    }
    elsif(defined $15)
    {
      if($units{'centuries'}) { $error = 1; last }
      $units{'centuries'} = $5;
    }
    elsif(defined $17)
    {
      $error = 1;
      last;
    }
  }

  if($error)
  {
    $self->error("Could not parse interval '$value' - found overlaping time units");
    return undef;
  }

  if($value_pos != length($value)) 
  {
    $self->error("Could not parse interval '$value' - could not interpret all tokens");
    return undef;
  }

  if(defined $units{'millenniums'})
  {
    $units{'years'} += 1000 * $units{'millenniums'};
    delete $units{'millenniums'};
  }

  if(defined $units{'centuries'})
  {
    $units{'years'} += 100 * $units{'centuries'};
    delete $units{'centuries'};
  }

  if(defined $units{'decades'})
  {
    $units{'years'} += 10 * $units{'decades'};
    delete $units{'decades'};
  }

  if($units{'hours'} || $units{'minutes'} || $units{'seconds'})
  {
    my $seconds = ($units{'hours'}   || 0) * 60 * 60 +
                  ($units{'minutes'} || 0) * 60 +
                  ($units{'seconds'} || 0);
    $units{'hours'}   = int($seconds  / 3600);
    $seconds         -= $units{'hours'} * 3600;
    $units{'minutes'} = int($seconds  / 60);
    $units{'seconds'} = $seconds - $units{'minutes'} * 60;
  }

  $units{'end_of_month'} = $end_of_month_mode  if(defined $end_of_month_mode);

  $dt_duration = $is_ago ? 
    DateTime::Duration->new(%units)->inverse :
    DateTime::Duration->new(%units);

  return $dt_duration;
}

sub format_interval
{
  my($self, $dur) = @_;

  if(!defined $dur || $self->validate_interval_keyword($dur) ||
     $dur =~ /^\w+\(.*\)$/)
  {
    return $dur;
  }

  my $output = '';

  my(%deltas, %unit, $neg);

  @deltas{qw/years mons days h m s/} =
    $dur->in_units(qw/years months days hours minutes seconds/);

  foreach (qw/years mons days/)
  {
    $unit{$_} = $_;
    $unit{$_} =~ s/s\z// if $deltas{$_} == 1;
  }

  $output .= "$deltas{'years'} $unit{'years'} "  if($deltas{'years'});
  $neg = 1  if($deltas{'years'} < 0);

  $output .= '+' if ($neg && $deltas{'mons'} > 0);
  $output .= "$deltas{'mons'} $unit{'mons'} "  if($deltas{'mons'});
  $neg = $deltas{'mons'}  < 0 ? 1 :
         $deltas{'mons'}      ? 0 : 
         $neg;

  $output .= '+'  if($neg && $deltas{'days'} > 0);
  $output .= "$deltas{'days'} $unit{'days'} "  if($deltas{'days'});

  if($deltas{'h'} || $deltas{'m'} || $deltas{'s'} || $dur->nanoseconds)
  {
    $neg = $deltas{'days'}  < 0 ? 1 :
           $deltas{'days'}      ? 0 :
           $neg;

    if($neg && (($deltas{'h'} > 0) || (!$deltas{'h'} &&  $deltas{'m'} > 0) ||
                (!$deltas{'h'} && !$deltas{'m'} && $deltas{'s'} > 0)))
    {
      $output .= '+';
    }

    my $nsec = $dur->nanoseconds;

    $output .= '-'  if(!$deltas{'h'} && ($deltas{'m'} < 0 || $deltas{'s'} < 0));
    @deltas{qw/m s/} = (abs($deltas{'m'}), abs($deltas{'s'}));
    $deltas{'hms'} = join(':', map { sprintf('%.2d', $deltas{$_}) } (qw/h m/)) .
                     ($nsec ? sprintf(':%02d.%09d', $deltas{'s'}, $nsec) :         
                              sprintf(':%02d', $deltas{'s'}));

    $output .= "$deltas{'hms'}"  if($deltas{'hms'});
  }

  $output =~ s/ \z//;

  if(length($output) > $self->max_interval_characters)
  {
    Carp::croak "Interval string is longer than ", ref($self),
                "->max_interval_characters (", $self->max_interval_characters,
                ") characters long: $output";
  }

  return $output;
}

sub build_dsn { 'override in subclass' }

sub validate_boolean_keyword
{
  no warnings;
  $_[1] =~ /^(?:TRUE|FALSE)$/;
}

sub validate_date_keyword      { 0 }
sub validate_datetime_keyword  { 0 }
sub validate_time_keyword      { 0 }
sub validate_timestamp_keyword { 0 }
sub validate_interval_keyword  { 0 }

sub next_value_in_sequence
{
  my($self, $seq) = @_;
  $self->error("Don't know how to select next value in sequence '$seq' " .
               "for database driver " . $self->driver);
  return undef;
}

sub auto_sequence_name { undef }

sub supports_limit_with_offset { 1 }
sub supports_arbitrary_defaults_on_insert { 0 }
sub supports_select_from_subselect        { 0 }
sub format_select_from_subselect { "(\n$_[1]\n  )" }

sub likes_redundant_join_conditions { 0 }
sub likes_lowercase_table_names     { 0 }
sub likes_lowercase_schema_names    { 0 }
sub likes_lowercase_catalog_names   { 0 }
sub likes_lowercase_sequence_names  { 0 }
sub likes_implicit_joins            { 0 }

sub supports_schema  { 0 }
sub supports_catalog { 0 }

sub format_limit_with_offset
{
  #my($self, $limit, $offset) = @_;
  return @_ > 2 ? "$_[1] OFFSET $_[2]" : $_[1];
}

sub format_table_with_alias
{
  #my($self, $table, $alias, $hints) = @_;
  return "$_[1] $_[2]";
}

sub supports_on_duplicate_key_update { 0 }

#
# DBI introspection
#

sub refine_dbi_column_info
{
  my($self, $col_info) = @_;

  # Parse odd default value syntaxes  
  $col_info->{'COLUMN_DEF'} = 
    $self->parse_dbi_column_info_default($col_info->{'COLUMN_DEF'}, $col_info);

  # Make sure the data type name is lowercase
  $col_info->{'TYPE_NAME'} = lc $col_info->{'TYPE_NAME'};

  # Unquote column name
  $col_info->{'COLUMN_NAME'} = $self->unquote_column_name($col_info->{'COLUMN_NAME'});

  return;
}

sub refine_dbi_foreign_key_info
{
  my($self, $fk_info) = @_;

  # Unquote column names
  foreach my $param (qw(FK_COLUMN_NAME UK_COLUMN_NAME))
  {
    $fk_info->{$param} = $self->unquote_column_name($fk_info->{$param});
  }

  return;
}

sub parse_dbi_column_info_default { $_[1] }

sub list_tables
{
  my($self, %args) = @_;

  my $types = $args{'include_views'} ? "'TABLE','VIEW'" : 'TABLE';
  my @tables;

  eval
  {
    my $dbh = $self->dbh or die $self->error;

    local $dbh->{'RaiseError'} = 1;
    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $sth = $dbh->table_info($self->catalog, $self->schema, '%', $types);

    $sth->execute;

    while(my $table_info = $sth->fetchrow_hashref)
    {
      push(@tables, $table_info->{'TABLE_NAME'})
    }
  };

  if($@)
  {
    Carp::croak "Could not list tables from ", $self->dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

#
# Storable hooks
#

sub STORABLE_freeze 
{
  my($self, $cloning) = @_;

  return  if($cloning);

  # Ditch the DBI $dbh and pull the password out of its closure
  my $db = { %$self };
  $db->{'dbh'} = undef;
  $db->{'password'} = $self->password;
  $db->{'password_closure'} = undef;

  require Storable;
  return Storable::freeze($db);
}

sub STORABLE_thaw
{
  my($self, $cloning, $serialized) = @_;

  %$self = %{ Storable::thaw($serialized) };

  # Put the password back in a closure
  my $password = delete $self->{'password'};
  $self->{'password_closure'} = sub { $password }  if(defined $password);
}

#
# This is both a class and an object method
#

sub error
{
  my($self_or_class) = shift;

  if(ref $self_or_class) # Object method
  {
    if(@_)
    {
      return $self_or_class->{'error'} = $Error = shift;
    }
    return $self_or_class->{'error'};  
  }

  # Class method
  return $Error = shift  if(@_);
  return $Error;
}

sub DESTROY
{
  $_[0]->disconnect;
}

BEGIN
{
  package Rose::DateTime::Format::Generic;

  use Rose::Object;
  our @ISA = qw(Rose::Object);

  use Rose::Object::MakeMethods::Generic
  (
    scalar  => 'server_tz',
    boolean => 'european',
  );

  sub format_date      { shift; Rose::DateTime::Util::format_date($_[0], '%Y-%m-%d') }
  sub format_datetime  { shift; Rose::DateTime::Util::format_date($_[0], '%Y-%m-%d %T') }
  sub format_timestamp { shift; Rose::DateTime::Util::format_date($_[0], '%Y-%m-%d %H:%M:%S.%N') }

  sub parse_date       { shift; Rose::DateTime::Util::parse_date($_[0]) }
  sub parse_datetime   { shift; Rose::DateTime::Util::parse_date($_[0]) }
  sub parse_timestamp  { shift; Rose::DateTime::Util::parse_date($_[0]) }
}

1;

__END__

=head1 NAME

Rose::DB - A DBI wrapper and abstraction layer.

=head1 SYNOPSIS

  package My::DB;

  use Rose::DB;
  our @ISA = qw(Rose::DB);

  My::DB->register_db(
    domain   => 'development',
    type     => 'main',
    driver   => 'Pg',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
    server_time_zone => 'UTC',
  );

  My::DB->register_db(
    domain   => 'production',
    type     => 'main',
    driver   => 'Pg',
    database => 'big_db',
    host     => 'dbserver.acme.com',
    username => 'dbadmin',
    password => 'prodsecret',
    server_time_zone => 'UTC',
  );

  My::DB->default_domain('development');
  My::DB->default_type('main');
  ...

  $db = My::DB->new;

  my $dbh = $db->dbh or die $db->error;

  $db->begin_work or die $db->error;
  $dbh->do(...)   or die $db->error;
  $db->commit     or die $db->error;

  $db->do_transaction(sub
  {
    $dbh->do(...);
    $sth = $dbh->prepare(...);
    $sth->execute(...);
    while($sth->fetch) { ... }
    $dbh->do(...);
  }) 
  or die $db->error;

  $dt  = $db->parse_timestamp('2001-03-05 12:34:56.123');
  $val = $db->format_timestamp($dt);

  $dt  = $db->parse_datetime('2001-03-05 12:34:56');
  $val = $db->format_datetime($dt);

  $dt  = $db->parse_date('2001-03-05');
  $val = $db->format_date($dt);

  $bit = $db->parse_bitfield('0x0AF', 32);
  $val = $db->format_bitfield($bit);

  ...

=head1 DESCRIPTION

L<Rose::DB> is a wrapper and abstraction layer for L<DBI>-related functionality.  A L<Rose::DB> object "has a" L<DBI> object; it is not a subclass of L<DBI>.

Please see the L<tutorial|Rose::DB::Tutorial> (perldoc Rose::DB::Tutorial) for an example usage scenario that reflects "best practices" for this module.

B<Tip:> Are you looking for an object-relational mapper (ORM)?  If so, please see the L<Rose::DB::Object> module.  L<Rose::DB::Object> is an ORM that uses this module to manage its database connections.  L<Rose::DB> alone is simply a data source abstraction layer; it is not an ORM.

=head1 DATABASE SUPPORT

L<Rose::DB> currently supports the following L<DBI> database drivers:

    DBD::Pg       (PostgreSQL)
    DBD::mysql    (MySQL)
    DBD::SQLite   (SQLite)
    DBD::Informix (Informix)

Oracle (L<DBD::Oracle>) is I<partially> supported, but some features may not yet work correctly.

L<Rose::DB> will attempt to service an unsupported database using a L<generic|Rose::DB::Generic> implementation that may or may not work.  Support for more drivers may be added in the future.  Patches are welcome.

All database-specific behavior is contained and documented in the subclasses of L<Rose::DB>.  L<Rose::DB>'s constructor method (L<new()|/new>) returns  a database-specific subclass of L<Rose::DB>, chosen based on the L<driver|/driver> value of the selected L<data source|"Data Source Abstraction">.  The default mapping of databases to L<Rose::DB> subclasses is:

    DBD::Pg       -> Rose::DB::Pg
    DBD::mysql    -> Rose::DB::MySQL
    DBD::SQLite   -> Rose::DB::SQLite
    DBD::Informix -> Rose::DB::Informix
    DBD::Oracle   -> Rose::DB::Oracle

This mapping can be changed using the L<driver_class|/driver_class> class method.

The L<Rose::DB> object method documentation found here defines the purpose of each method, as well as the default behavior of the method if it is not overridden by a subclass.  You must read the subclass documentation to learn about behaviors that are specific to each type of database.

Subclasses may also add methods that do not exist in the parent class, of course.  This is yet another reason to read the documentation for the subclass that corresponds to your data source's database software.

=head1 FEATURES

The basic features of L<Rose::DB> are as follows.

=head2 Data Source Abstraction

Instead of dealing with "databases" that exist on "hosts" or are located via some vendor-specific addressing scheme, L<Rose::DB> deals with "logical" data sources.  Each logical data source is currently backed by a single "physical" database (basically a single L<DBI> connection).

Multiplexing, fail-over, and other more complex relationships between logical data sources and physical databases are not part of L<Rose::DB>.  Some basic types of fail-over may be added to L<Rose::DB> in the future, but right now the mapping is strictly one-to-one.  (I'm also currently inclined to encourage multiplexing functionality to exist in a layer above L<Rose::DB>, rather than within it or in a subclass of it.)

The driver type of the data source determines the functionality of all methods that do vendor-specific things (e.g., L<column value parsing and formatting|"Vendor-Specific Column Value Parsing and Formatting">).

L<Rose::DB> identifies data sources using a two-level namespace made of a "domain" and a "type".  Both are arbitrary strings.  If left unspecified, the default domain and default type (accessible via L<Rose::DB>'s L</default_domain> and L</default_type> class methods) are assumed.

There are many ways to use the two-level namespace, but the most common is to use the domain to represent the current environment (e.g., "development", "staging", "production") and then use the type to identify the logical data source within that environment (e.g., "report", "main", "archive")

A typical deployment scenario will set the default domain using the L</default_domain> class method as part of the configure/install process.  Within application code, L<Rose::DB> objects can be constructed by specifying type alone:

    $main_db    = Rose::DB->new(type => 'main');
    $archive_db = Rose::DB->new(type => 'archive');

If there is only one database type, then all L<Rose::DB> objects can be instantiated with a bare constructor call like this:

    $db = Rose::DB->new;

Again, remember that this is just one of many possible uses of domain and type.  Arbitrarily complex scenarios can be created by nesting namespaces within one or both parameters (much like how Perl uses "::" to create a multi-level namespace from single strings).

The important point is the abstraction of data sources so they can be identified and referred to using a vocabulary that is entirely independent of the actual DSN (data source names) used by L<DBI> behind the scenes.

=head2 Database Handle Life-Cycle Management

When a L<Rose::DB> object is destroyed while it contains an active L<DBI> database handle, the handle is explicitly disconnected before destruction.  L<Rose::DB> supports a simple retain/release reference-counting system which allows a database handle to out-live its parent L<Rose::DB> object.

In the simplest case, L<Rose::DB> could be used for its data source abstractions features alone. For example, transiently creating a L<Rose::DB> and then retaining its L<DBI> database handle before it is destroyed:

    $main_dbh = Rose::DB->new(type => 'main')->retain_dbh 
                  or die Rose::DB->error;

    $aux_dbh  = Rose::DB->new(type => 'aux')->retain_dbh  
                  or die Rose::DB->error;

If the database handle was simply extracted via the L<dbh|/dbh> method instead of retained with L<retain_dbh|/retain_dbh>, it would be disconnected by the time the statement completed.

    # WRONG: $dbh will be disconnected immediately after the assignment!
    $dbh = Rose::DB->new(type => 'main')->dbh or die Rose::DB->error;

=head2 Vendor-Specific Column Value Parsing and Formatting

Certain semantically identical column types are handled differently in different databases.  Date and time columns are good examples.  Although many databases  store month, day, year, hours, minutes, and seconds using a "datetime" column type, there will likely be significant differences in how each of those databases expects to receive such values, and how they're returned.

L<Rose::DB> is responsible for converting the wide range of vendor-specific column values for a particular column type into a single form that is convenient for use within Perl code.  L<Rose::DB> also handles the opposite task, taking input from the Perl side and converting it into the appropriate format for a specific database.  Not all column types that exist in the supported databases are handled by L<Rose::DB>, but support will expand in the future.

Many column types are specific to a single database and do not exist elsewhere.  When it is reasonable to do so, vendor-specific column types may be "emulated" by L<Rose::DB> for the benefit of other databases.  For example, an ARRAY value may be stored as a specially formatted string in a VARCHAR field in a database that does not have a native ARRAY column type.

L<Rose::DB> does B<NOT> attempt to present a unified column type system, however.  If a column type does not exist in a particular kind of database, there should be no expectation that L<Rose::DB> will be able to parse and format that value type on behalf of that database.

=head2 High-Level Transaction Support

Transactions may be started, committed, and rolled back in a variety of ways using the L<DBI> database handle directly.  L<Rose::DB> provides wrappers to do the same things, but with different error handling and return values.  There's also a method (L</do_transaction>) that will execute arbitrary code within a single transaction, automatically handling rollback on failure and commit on success.

=head1 SUBCLASSING

Subclassing is B<strongly encouraged> and generally works as expected.  (See the L<tutorial|Rose::DB::Tutorial> for a complete example.)  There is, however, the question of how class data is shared with subclasses.  Here's how it works for the various pieces of class data.

=over

=item B<alias_db>, B<modify_db>, B<register_db>, B<unregister_db>, B<unregister_domain>

By default, all subclasses share the same data source "registry" with L<Rose::DB>.  To provide a private registry for your subclass (the recommended approach), see the example in the documentation for the L<registry|/registry> method below.

=item B<default_domain>, B<default_type>

If called with no arguments, and if the attribute was never set for this
class, then a left-most, breadth-first search of the parent classes is
initiated.  The value returned is taken from first parent class 
encountered that has ever had this attribute set.

(These attributes use the L<inheritable_scalar|Rose::Class::MakeMethods::Generic/inheritable_scalar> method type as defined in L<Rose::Class::MakeMethods::Generic>.)

=item B<driver_class>, B<default_connect_options>

These hashes of attributes are inherited by subclasses using a one-time, shallow copy from a superclass.  Any subclass that accesses or manipulates the hash in any way will immediately get its own private copy of the hash I<as it exists in the superclass at the time of the access or manipulation>.  

The superclass from which the hash is copied is the closest ("least super") class that has ever accessed or manipulated this hash.  The copy is a "shallow" copy, duplicating only the keys and values.  Reference values are not recursively copied.

Setting to hash to undef (using the 'reset' interface) will cause it to be re-copied from a superclass the next time it is accessed.

(These attributes use the L<inheritable_hash|Rose::Class::MakeMethods::Generic/inheritable_hash> method type as defined in L<Rose::Class::MakeMethods::Generic>.)

=back

=head1 SERIALIZATION

A L<Rose::DB> object may contain a L<DBI> database handle, and L<DBI> database handles usually don't survive the serialize process intact.  L<Rose::DB> objects also hide database passwords inside closures, which also don't serialize well.    In order for a L<Rose::DB> object to survive serialization, custom hooks are required.

L<Rose::DB> has hooks for the L<Storable> serialization module, but there is an important caveat.  Since L<Rose::DB> objects are blessed into a dynamically generated class (derived from the L<driver class|/driver_class>), you must load your L<Rose::DB>-derived class with all its registered data sources before you can successfully L<thaw|Storable/thaw> a L<frozen|Storable/freeze> L<Rose::DB>-derived object.  Here's an example.

Imagine that this is your L<Rose::DB>-derived class:

    package My::DB;

    use Rose::DB;
    our @ISA = qw(Rose::DB);

    My::DB->register_db(
      domain   => 'dev',
      type     => 'main',
      driver   => 'Pg',
      ...
    );

    My::DB->register_db(
      domain   => 'prod',
      type     => 'main',
      driver   => 'Pg',
      ...
    );

    My::DB->default_domain('dev');
    My::DB->default_type('main');

In one program, a C<My::DB> object is L<frozen|Storable/freeze> using L<Storable>:

    # my_freeze_script.pl

    use My::DB;
    use Storable qw(nstore);

    # Create My::DB object
    $db = My::DB->new(domain => 'dev', type => 'main');

    # Do work...
    $db->dbh->db('CREATE TABLE some_table (...)');
    ...

    # Serialize $db and store it in frozen_data_file
    nstore($db, 'frozen_data_file');

Now another program wants to L<thaw|Storable/thaw> out that C<My::DB> object and use it.  To do so, it must be sure to load the L<My::DB> module (which registers all its data sources when loaded) I<before> attempting to deserialize the C<My::DB> object serialized by C<my_freeze_script.pl>.

    # my_thaw_script.pl

    # IMPORTANT: load db modules with all data sources registered before
    #            attempting to deserialize objects of this class.
    use My::DB; 

    use Storable qw(retrieve);

    # Retrieve frozen My::DB object from frozen_data_file
    $db = retrieve('frozen_data_file');

    # Do work...
    $db->dbh->db('DROP TABLE some_table');
    ...

Note that this rule about loading a L<Rose::DB>-derived class with all its data sources registered prior to deserializing such an object only applies if the serialization was done in a different process.  If you L<freeze|Storable/freeze> and L<thaw|Storable/thaw> within the same process, you don't have to worry about it.

=head1 CLASS METHODS

=over 4

=item B<alias_db PARAMS>

Make one data source an alias for another by pointing them both to the same registry entry.  PARAMS are name/value pairs that must include domain and type values for both the source and alias parameters.  Example:

    Rose::DB->alias_db(source => { domain => 'dev', type => 'main' },
                       alias  => { domain => 'dev', type => 'aux' });

This makes the "dev/aux" data source point to the same registry entry as the "dev/main" data source.  Modifications to either registry entry (via L<modify_db|/modify_db>) will be reflected in both.

=item B<db_exists PARAMS>

Returns true of the data source specified by PARAMS is registered, false otherwise.  PARAMS are name/value pairs for C<domain> and C<type>.  If they are omitted, they default to L<default_domain|/default_domain> and L<default_type|/default_type>, respectively.  If default values do not exist, a fatal error will occur.  If a single value is passed instead of name/value pairs, it is taken as the value of the C<type> parameter.

=item B<default_connect_options [HASHREF | PAIRS]>

Get or set the default L<DBI> connect options hash.  If a reference to a hash is passed, it replaces the default connect options hash.  If a series of name/value pairs are passed, they are added to the default connect options hash.

The default set of default connect options is:

    AutoCommit => 1,
    RaiseError => 1,
    PrintError => 1,
    ChopBlanks => 1,
    Warn       => 0,

See the L<connect_options|/connect_options> object method for more information on how the default connect options are used.

=item B<default_domain [DOMAIN]>

Get or set the default data source domain.  See the L<"Data Source Abstraction"> section for more information on data source domains.

=item B<default_type [TYPE]>

Get or set the default data source type.  See the L<"Data Source Abstraction"> section for more information on data source types.

=item B<driver_class DRIVER [, CLASS]>

Get or set the subclass used for DRIVER.  The DRIVER argument is automatically converted to lowercase.  (Driver names are effectively case-insensitive.)

    $class = Rose::DB->driver_class('Pg');      # get
    Rose::DB->driver_class('pg' => 'MyDB::Pg'); # set

The default mapping of driver names to class names is as follows:

    mysql    -> Rose::DB::MySQL
    pg       -> Rose::DB::Pg
    informix -> Rose::DB::Informix
    sqlite   -> Rose::DB::SQLite
    oracle   -> Rose::DB::Oracle
    generic  -> Rose::DB::Generic

The class mapped to the special driver name "generic" will be used for any driver name that does not have an entry in the map.

See the documentation for the L<new|/new> method for more information on how the driver influences the class of objects returned by the constructor.

=item B<modify_db PARAMS>

Modify a data source, setting the attributes specified in PARAMS, where
PARAMS are name/value pairs.  Any L<Rose::DB> object method that sets a L<data source configuration value|"Data Source Configuration"> is a valid parameter name.

    # Set new username for data source identified by domain and type
    Rose::DB->modify_db(domain   => 'test', 
                        type     => 'main',
                        username => 'tester');

PARAMS should include values for both the C<type> and C<domain> parameters since these two attributes are used to identify the data source.  If they are omitted, they default to L<default_domain|/default_domain> and L<default_type|/default_type>, respectively.  If default values do not exist, a fatal error will occur.  If there is no data source defined for the specified C<type> and C<domain>, a fatal error will occur.

=item B<register_db PARAMS>

Registers a new data source with the attributes specified in PARAMS, where
PARAMS are name/value pairs.  Any L<Rose::DB> object method that sets a L<data source configuration value|"Data Source Configuration"> is a valid parameter name.

PARAMS B<must> include a value for the C<driver> parameter.  If the C<type> or C<domain> parameters are omitted or undefined, they default to the return values of the L<default_type|/default_type> and L<default_domain|/default_domain> class methods, respectively.

The C<type> and C<domain> are used to identify the data source.  If either one is missing, a fatal error will occur.  See the L<"Data Source Abstraction"> section for more information on data source types and domains.

The C<driver> is used to determine which class objects will be blessed into by the L<Rose::DB> constructor, L<new|/new>.  The driver name is automatically converted to lowercase.  If it is missing, a fatal error will occur.  

In most deployment scenarios, L<register_db|/register_db> is called early in the compilation process to ensure that the registered data sources are available when the "real" code runs.

Database registration can be included directly in your L<Rose::DB> subclass.  This is the recommended approach.  Example:

    package My::DB;

    use Rose::DB;
    our @ISA = qw(Rose::DB);

    # Use a private registry for this class
    __PACKAGE__->use_private_registry;

    # Register data sources
    My::DB->register_db(
      domain   => 'development',
      type     => 'main',
      driver   => 'Pg',
      database => 'dev_db',
      host     => 'localhost',
      username => 'devuser',
      password => 'mysecret',
    );

    My::DB->register_db(
      domain   => 'production',
      type     => 'main',
      driver   => 'Pg',
      database => 'big_db',
      host     => 'dbserver.acme.com',
      username => 'dbadmin',
      password => 'prodsecret',
    );
    ...

Another possible approach is to consolidate data source registration in a single module which is then C<use>ed early on in the code path.  For example, imagine a mod_perl web server environment:

    # File: MyCorp/DataSources.pm
    package MyCorp::DataSources;

    My::DB->register_db(
      domain   => 'development',
      type     => 'main',
      driver   => 'Pg',
      database => 'dev_db',
      host     => 'localhost',
      username => 'devuser',
      password => 'mysecret',
    );

    My::DB->register_db(
      domain   => 'production',
      type     => 'main',
      driver   => 'Pg',
      database => 'big_db',
      host     => 'dbserver.acme.com',
      username => 'dbadmin',
      password => 'prodsecret',
    );
    ...

    # File: /usr/local/apache/conf/startup.pl

    use My::DB; # your Rose::DB subclass
    use MyCorp::DataSources; # register all data sources
    ...

Data source registration can happen at any time, of course, but it is most useful when all application code can simply assume that all the data sources are already registered.  Doing the registration as early as possible (e.g., directly in your L<Rose::DB> subclass, or in a C<startup.pl> file that is loaded from an apache/mod_perl web server's C<httpd.conf> file) is the best way to create such an environment.

Note that the data source registry serves as an I<initial> source of information for L<Rose::DB> objects.  Once an object is instantiated, it is independent of the registry.  Changes to an object are not reflected in the registry, and changes to the registry are not reflected in existing objects.

=item B<registry [REGISTRY]>

Get or set the L<Rose::DB::Registry>-derived object that manages and stores the data source registry.  It defaults to an "empty" L<Rose::DB::Registry> object.  Remember that setting a new registry will replace the existing registry and all the data sources registered in it.

Note that L<Rose::DB> subclasses will inherit the base class's L<Rose::DB::Registry> object and will therefore inherit all existing registry entries and share the same registry namespace as the base class.   This may or may not be what you want.

In most cases, it's wise to give your subclass its own private registry if it inherits directly from L<Rose::DB>.  To do that, just set a new registry object in your subclass.  Example:

    package My::DB;

    use Rose::DB;
    our @ISA = qw(Rose::DB);

    # Create a private registry for this class:
    #
    # either explicitly:
    # use Rose::DB::Registry;
    # __PACKAGE__->registry(Rose::DB::Registry->new);
    #
    # or use the convenience method:
    __PACKAGE__->use_private_registry;
    ...

Further subclasses of C<My::DB> may then inherit its registry object, if desired, or may create their own private registries in the manner shown above.

=item B<unregister_db PARAMS>

Unregisters the data source having the C<type> and C<domain> specified in  PARAMS, where PARAMS are name/value pairs.  Returns true if the data source was unregistered successfully, false if it did not exist in the first place.  Example:

    Rose::DB->unregister_db(type => 'main', domain => 'test');

PARAMS B<must> include values for both the C<type> and C<domain> parameters since these two attributes are used to identify the data source.  If either one is missing, a fatal error will occur.

Unregistering a data source removes all knowledge of it.  This may be harmful to any existing L<Rose::DB> objects that are associated with that data source.

=item B<unregister_domain DOMAIN>

Unregisters an entire domain.  Returns true if the domain was unregistered successfully, false if it did not exist in the first place.  Example:

    Rose::DB->unregister_domain('test');

Unregistering a domain removes all knowledge of all of the data sources that existed under it.  This may be harmful to any existing L<Rose::DB> objects that are associated with any of those data sources.

=item B<use_private_registry>

This method is used to give a class its own private L<registry|/registry>.  In other words, this:

    __PACKAGE__->use_private_registry;

is roughly equivalent to this:

    use Rose::DB::Registry;
    __PACKAGE__->registry(Rose::DB::Registry->new);

=back

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.  Example:

    $db = Rose::DB->new(type => 'main', domain => 'qa');

If a single argument is passed to L<new|/new>, it is used as the C<type> value:

    $db = Rose::DB->new(type => 'aux'); 
    $db = Rose::DB->new('aux'); # same thing

Each L<Rose::DB> object is associated with a particular data source, defined by the L<type|/type> and L<domain|/domain> values.  If these are not part of PARAMS, then the default values are used.  If you do not want to use the default values for the L<type|/type> and L<domain|/domain> attributes, you should specify them in the constructor PARAMS.

The default L<type|/type> and L<domain|/domain> can be set using the L<default_type|/default_type> and L<default_domain|/default_domain> class methods.  See the L<"Data Source Abstraction"> section for more information on data sources.

The object returned by L<new|/new> will be derived from a database-specific driver class, chosen based on the L<driver|/driver> value of the selected data source.  If there is no registered data source for the specified L<type|/type> and L<domain|/domain>, a fatal error will occur.

The default driver-to-class mapping is as follows:

    pg       -> Rose::DB::Pg
    mysql    -> Rose::DB::MySQL
    informix -> Rose::DB::Informix
    oracle   -> Rose::DB::Oracle
    sqlite   -> Rose::DB::SQLite

You can change this mapping with the L<driver_class|/driver_class> class method.

=back

=head1 OBJECT METHODS

=over 4

=item B<begin_work>

Attempt to start a transaction by calling the L<begin_work|DBI/begin_work> method on the L<DBI> database handle.

If necessary, the database handle will be constructed and connected to the current data source.  If this fails, undef is returned.  If there is no registered data source for the current C<type> and C<domain>, a fatal error will occur.

If the "AutoCommit" database handle attribute is false, the handle is assumed to already be in a transaction and L<Rose::DB::Constants::IN_TRANSACTION|Rose::DB::Constants> (-1) is returned.  If the call to L<DBI>'s L<begin_work|DBI/begin_work> method succeeds, 1 is returned.  If it fails, undef is returned.

=item B<commit>

Attempt to commit the current transaction by calling the L<commit|DBI/commit> method on the L<DBI> database handle.  If the L<DBI> database handle does not exist or is not connected, 0 is returned.

If the "AutoCommit" database handle attribute is true, the handle is assumed to not be in a transaction and L<Rose::DB::Constants::IN_TRANSACTION|Rose::DB::Constants> (-1) is returned.  If the call to L<DBI>'s L<commit|DBI/commit> method succeeds, 1 is returned.  If it fails, undef is returned.

=item B<connect>

Constructs and connects the L<DBI> database handle for the current data source.  If there is no registered data source for the current L<type|/type> and L<domain|/domain>, a fatal error will occur.

If any L<post_connect_sql|/post_connect_sql> statement failed to execute, the database handle is disconnected and then discarded.

Returns true if the database handle was connected successfully and all L<post_connect_sql|/post_connect_sql> statements (if any) were run successfully, false otherwise.  

=item B<connect_option NAME [, VALUE]>

Get or set a single connection option.  Example:

    $val = $db->connect_option('RaiseError'); # get
    $db->connect_option(AutoCommit => 1);     # set

Connection options are name/value pairs that are passed in a hash reference as the fourth argument to the call to L<DBI-E<gt>connect()|DBI/connect>.  See the L<DBI> documentation for descriptions of the various options.

=item B<connect_options [HASHREF | PAIRS]>

Get or set the L<DBI> connect options hash.  If a reference to a hash is passed, it replaces the connect options hash.  If a series of name/value pairs are passed, they are added to the connect options hash.

Returns a reference to the connect options has in scalar context, or a list of name/value pairs in list context.

=item B<dbh [DBH]>

Get or set the L<DBI> database handle connected to the current data source.  If the database handle does not exist or is not already connected, this method will do everything necessary to do so.

Returns undef if the database handle could not be constructed and connected.  If there is no registered data source for the current C<type> and C<domain>, a fatal error will occur.

Note: when setting this attribute, you I<must> pass in a L<DBI> database handle that has the same L<driver|/driver> as the object.  For example, if the L<driver|/driver> is C<mysql> then the L<DBI> database handle must be connected to a MySQL database.  Passing in a mismatched database handle will cause a fatal error.

=item B<disconnect>

Decrements the reference count for the database handle and disconnects it if the reference count is zero.  Regardless of the reference count, it sets the L<dbh|/dbh> attribute to undef.

Returns true if all L<pre_disconnect_sql|/pre_disconnect_sql> statements (if any) were run successfully and the database handle was disconnected successfully (or if it was simply set to undef), false otherwise.

The database handle will not be disconnected if any L<pre_disconnect_sql|/pre_disconnect_sql> statement fails to execute, and the L<pre_disconnect_sql|/pre_disconnect_sql> is not run unless the handle is going to be disconnected.

=item B<do_transaction CODE [, ARGS]>

Execute arbitrary code within a single transaction, rolling back if any of the code fails, committing if it succeeds.  CODE should be a code reference.  It will be called with any arguments passed to L<do_transaction|/do_transaction> after the code reference.  Example:

    # Transfer $100 from account id 5 to account id 9
    $db->do_transaction(sub
    {
      my($amt, $id1, $id2) = @_;

      my $dbh = $db->dbh or die $db->error;

      # Transfer $amt from account id $id1 to account id $id2
      $dbh->do("UPDATE acct SET bal = bal - $amt WHERE id = $id1");
      $dbh->do("UPDATE acct SET bal = bal + $amt WHERE id = $id2");
    },
    100, 5, 9) or warn "Transfer failed: ", $db->error;

=item B<error [MSG]>

Get or set the error message associated with the last failure.  If a method fails, check this attribute to get the reason for the failure in the form of a text message.

=item B<has_dbh>

Returns true if the object has a L<DBI> database handle (L<dbh|/dbh>), false if it does not.

=item B<has_primary_key [ TABLE | PARAMS ]>

Returns true if the specified table has a primary key (as determined by the L<primary_key_column_names|/primary_key_column_names> method), false otherwise.  

The arguments are the same as those for the L<primary_key_column_names|/primary_key_column_names> method: either a table name or name/value pairs specifying C<table>, C<catalog>, and C<schema>.  The  C<catalog> and C<schema> parameters are optional and default to the return values of the L<catalog|/catalog> and L<schema|/schema> methods, respectively.  See the documentation for the L<primary_key_column_names|/primary_key_column_names> for more information.

=item B<init_db_info>

Initialize data source configuration information based on the current values of the L<type|/type> and L<domain|/domain> attributes by pulling data from the corresponding registry entry.  If there is no registered data source for the current L<type|/type> and L<domain|/domain>, a fatal error will occur.  L<init_db_info|/init_db_info> is called as part of the L<new|/new> and L<connect|/connect> methods.

=item B<insertid_param>

Returns the name of the L<DBI> statement handle attribute that contains the auto-generated unique key created during the last insert operation.  Returns undef if the current data source does not support this attribute.

=item B<last_insertid_from_sth STH>

Given a L<DBI> statement handle, returns the value of the auto-generated unique key created during the last insert operation.  This value may be undefined if this feature is not supported by the current data source.

=item B<list_tables>

Returns a list (in list context) or reference to an array (in scalar context) of tables in the database.  The current L<catalog|/catalog> and L<schema|/schema> are honored.

=item B<quote_column_name NAME>

Returns the column name NAME appropriately quoted for use in an SQL statement.  (Note that "appropriate" quoting may mean no quoting at all.)

=item B<release_dbh>

Decrements the reference count for the L<DBI> database handle, if it exists.  Returns 0 if the database handle does not exist.

If the reference count drops to zero, the database handle is disconnected.  Keep in mind that the L<Rose::DB> object itself will increment the reference count when the database handle is connected, and decrement it when L<disconnect|/disconnect> is called.

Returns true if the reference count is not 0 or if all L<pre_disconnect_sql|/pre_disconnect_sql> statements (if any) were run successfully and the database handle was disconnected successfully, false otherwise.

The database handle will not be disconnected if any L<pre_disconnect_sql|/pre_disconnect_sql> statement fails to execute, and the L<pre_disconnect_sql|/pre_disconnect_sql> is not run unless the handle is going to be disconnected.

See the L<"Database Handle Life-Cycle Management"> section for more information on the retain/release system.

=item B<retain_dbh>

Returns the connected L<DBI> database handle after incrementing the reference count.  If the database handle does not exist or is not already connected, this method will do everything necessary to do so.

Returns undef if the database handle could not be constructed and connected.  If there is no registered data source for the current L<type|/type> and L<domain|/domain>, a fatal error will occur.

See the L<"Database Handle Life-Cycle Management"> section for more information on the retain/release system.

=item B<rollback>

Roll back the current transaction by calling the L<rollback|DBI/rollback> method on the L<DBI> database handle.  If the L<DBI> database handle does not exist or is not connected, 0 is returned.

If the call to L<DBI>'s L<rollback|DBI/rollback> method succeeds or if auto-commit is enabled, 1 is returned.  If it fails, undef is returned.

=back

=head2 Data Source Configuration

Not all databases will use all of these values.  Values that are not supported are simply ignored.

=over 4

=item B<autocommit [VALUE]>

Get or set the value of the "AutoCommit" connect option and L<DBI> handle attribute.  If a VALUE is passed, it will be set in both the connect options hash and the current database handle, if any.  Returns the value of the "AutoCommit" attribute of the database handle if it exists, or the connect option otherwise.

This method should not be mixed with the L<connect_options|/connect_options> method in calls to L<register_db|/register_db> or L<modify_db|/modify_db> since L<connect_options|/connect_options> will overwrite I<all> the connect options with its argument, and neither L<register_db|/register_db> nor L<modify_db|/modify_db> guarantee the order that its parameters will be evaluated.

=item B<catalog [CATALOG]>

Get or set the database catalog name.  This setting is only relevant to databases that support the concept of catalogs.

=item B<connect_options [HASHREF | PAIRS]>

Get or set the options passed in a hash reference as the fourth argument to the call to L<DBI-E<gt>connect()|DBI/connect>.  See the L<DBI> documentation for descriptions of the various options.

If a reference to a hash is passed, it replaces the connect options hash.  If a series of name/value pairs are passed, they are added to the connect options hash.

Returns a reference to the hash of options in scalar context, or a list of name/value pairs in list context.

When L<init_db_info|/init_db_info> is called for the first time on an object (either in isolation or as part of the L<connect|/connect> process), the connect options are merged with the L<default_connect_options|/default_connect_options>.  The defaults are overridden in the case of a conflict.  Example:

    Rose::DB->register_db(
      domain   => 'development',
      type     => 'main',
      driver   => 'Pg',
      database => 'dev_db',
      host     => 'localhost',
      username => 'devuser',
      password => 'mysecret',
      connect_options =>
      {
        RaiseError => 0, 
        AutoCommit => 0,
      }
    );

    # Rose::DB->default_connect_options are:
    #
    # AutoCommit => 1,
    # ChopBlanks => 1,
    # PrintError => 1,
    # RaiseError => 1,
    # Warn       => 0,

    # The object's connect options are merged with default options 
    # since new() will trigger the first call to init_db_info()
    # for this object
    $db = Rose::DB->new(domain => 'development', type => 'main');

    # $db->connect_options are:
    #
    # AutoCommit => 0,
    # ChopBlanks => 1,
    # PrintError => 1,
    # RaiseError => 0,
    # Warn       => 0,

    $db->connect_options(TraceLevel => 2); # Add an option

    # $db->connect_options are now:
    #
    # AutoCommit => 0,
    # ChopBlanks => 1,
    # PrintError => 1,
    # RaiseError => 0,
    # TraceLevel => 2,
    # Warn       => 0,

    # The object's connect options are NOT re-merged with the default 
    # connect options since this will trigger the second call to 
    # init_db_info(), not the first
    $db->connect or die $db->error; 

    # $db->connect_options are still:
    #
    # AutoCommit => 0,
    # ChopBlanks => 1,
    # PrintError => 1,
    # RaiseError => 0,
    # TraceLevel => 2,
    # Warn       => 0,

=item B<database [NAME]>

Get or set the database name used in the construction of the DSN used in the L<DBI> L<connect|DBI/connect> call.

=item B<domain [DOMAIN]>

Get or set the data source domain.  See the L<"Data Source Abstraction"> section for more information on data source domains.

=item B<driver [DRIVER]>

Get or set the driver name.  The driver name can only be set during object construction (i.e., as an argument to L<new|/new>) since it determines the object class.  After the object is constructed, setting the driver to anything other than the same value it already has will cause a fatal error.

Even in the call to L<new|/new>, setting the driver name explicitly is not recommended.  Instead, specify the driver when calling L<register_db|/register_db> for each data source and allow the L<driver|/driver> to be set automatically based on the L<domain|/domain> and L<type|/type>.

The driver names for the L<currently supported database types|"DATABASE SUPPORT"> are:

    pg
    mysql
    informix
    oracle
    sqlite

Driver names should only use lowercase letters.

=item B<dsn [DSN]>

Get or set the L<DBI> DSN (Data Source Name) passed to the call to L<DBI>'s L<connect|DBI/connect> method.

If using L<DBI> version 1.43 or later, an attempt is made to parse the new DSN using L<DBI>'s L<parse_dsn|DBI/parse_dsn> method.  Any parts successfully extracted are assigned to the corresponding L<Rose::DB> attributes (e.g., host, port, database).

Note that an explicitly set DSN may render some other attributes inaccurate.  For example, the DSN may contain a host name that is different than the object's current L<host|/host> value.  If the host name is not successfully extracted from the DSN and applied to the object's L<host|/host> attribute, then the two values are out of sync.  I recommend not setting the DSN value explicitly unless you are also willing to manually synchronize (or ignore) the corresponding object attributes.

If the DSN is never set explicitly, it is initialized with the DSN constructed from the appropriate object attribute values when L<init_db_info|/init_db_info> or L<connect|/connect> is called.

=item B<host [NAME]>

Get or set the database server host name used in the construction of the DSN which is passed in the L<DBI> L<connect|DBI/connect> call.

=item B<password [PASS]>

Get or set the password that will be passed to the L<DBI> L<connect|DBI/connect> call.

=item B<port [NUM]>

Get or set the database server port number used in the construction of the DSN which is passed in the L<DBI> L<connect|DBI/connect> call.

=item B<pre_disconnect_sql [STATEMENTS]>

Get or set the SQL statements that will be run immediately before disconnecting from the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to the array of SQL statements in scalar context, or a list of SQL statements in list context.

The SQL statements are run in the order that they are supplied in STATEMENTS.  If any L<pre_disconnect_sql|/pre_disconnect_sql> statement fails when executed, the subsequent statements are ignored.

=item B<post_connect_sql [STATEMENTS]>

Get or set the SQL statements that will be run immediately after connecting to the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to the array of SQL statements in scalar context, or a list of SQL statements in list context.

The SQL statements are run in the order that they are supplied in STATEMENTS.  If any L<post_connect_sql|/post_connect_sql> statement fails when executed, the subsequent statements are ignored.

=item B<primary_key_column_names [ TABLE | PARAMS ]>

Returns a list (in list context) or reference to an array (in scalar context) of the names of the columns that make up the primary key for the specified table.  If the table has no primary key, an empty list (in list context) or reference to an empty array (in scalar context) will be returned.

The table may be specified in two ways.  If one argument is passed, it is taken as the name of the table.  Otherwise, name/value pairs are expected.  Valid parameter names are:

=over 4

=item C<catalog>

The name of the catalog that contains the table.  This parameter is optional and defaults to the return value of the L<catalog|/catalog> method.

=item C<schema>

The name of the schema that contains the table.  This parameter is optional and defaults to the return value of the L<schema|/schema> method.

=item C<table>

The name of the table.  This parameter is required.

=back

Case-sensitivity of names is determined by the underlying database.  If your database is case-sensitive, then you must pass names to this method with the expected case.

=item B<print_error [VALUE]>

Get or set the value of the "PrintError" connect option and L<DBI> handle attribute.  If a VALUE is passed, it will be set in both the connect options hash and the current database handle, if any.  Returns the value of the "PrintError" attribute of the database handle if it exists, or the connect option otherwise.

This method should not be mixed with the L<connect_options|/connect_options> method in calls to L<register_db|/register_db> or L<modify_db|/modify_db> since L<connect_options|/connect_options> will overwrite I<all> the connect options with its argument, and neither L<register_db|/register_db> nor L<modify_db|/modify_db> guarantee the order that its parameters will be evaluated.

=item B<raise_error [VALUE]>

Get or set the value of the "RaiseError" connect option and L<DBI> handle attribute.  If a VALUE is passed, it will be set in both the connect options hash and the current database handle, if any.  Returns the value of the "RaiseError" attribute of the database handle if it exists, or the connect option otherwise.

This method should not be mixed with the L<connect_options|/connect_options> method in calls to L<register_db|/register_db> or L<modify_db|/modify_db> since L<connect_options|/connect_options> will overwrite I<all> the connect options with its argument, and neither L<register_db|/register_db> nor L<modify_db|/modify_db> guarantee the order that its parameters will be evaluated.

=item B<schema [SCHEMA]>

Get or set the database schema name.  This setting is only useful to databases that support the concept of schemas (e.g., PostgreSQL).

=item B<server_time_zone [TZ]>

Get or set the time zone used by the database server software.  TZ should be a time zone name that is understood by L<DateTime::TimeZone>.  The default value is "floating".

See the L<DateTime::TimeZone> documentation for acceptable values of TZ.

=item B<type [TYPE]>

Get or set the  data source type.  See the L<"Data Source Abstraction"> section for more information on data source types.

=item B<username [NAME]>

Get or set the username that will be passed to the L<DBI> L<connect|DBI/connect> call.

=back

=head2 Value Parsing and Formatting

=over 4

=item B<format_bitfield BITS [, SIZE]>

Converts the L<Bit::Vector> object BITS into the appropriate format for the "bitfield" data type of the current data source.  If a SIZE argument is provided, the bit field will be padded with the appropriate number of zeros until it is SIZE bits long.  If the data source does not have a native "bit" or "bitfield" data type, a character data type may be used to store the string of 1s and 0s returned by the default implementation.

=item B<format_boolean VALUE>

Converts VALUE into the appropriate format for the "boolean" data type of the current data source.  VALUE is simply evaluated in Perl's scalar context to determine if it's true or false.

=item B<format_date DATETIME>

Converts the L<DateTime> object DATETIME into the appropriate format for the "date" (month, day, year) data type of the current data source.

=item B<format_datetime DATETIME>

Converts the L<DateTime> object DATETIME into the appropriate format for the "datetime" (month, day, year, hour, minute, second) data type of the current data source.

=item B<format_interval DURATION>

Converts the L<DateTime::Duration> object DURATION into the appropriate format for the interval (years, months, days, hours, minutes, seconds) data type of the current data source. If DURATION is undefined, a L<DateTime::Duration> object, a valid interval keyword (according to L<validate_interval_keyword|/validate_interval_keyword>), or if it looks like a function call (matches C</^\w+\(.*\)$/>) then it is returned unmodified.

=item B<format_time TIMECLOCK>

Converts the L<Time::Clock> object TIMECLOCK into the appropriate format for the time (hour, minute, second, fractional seconds) data type of the current data source.  Fractional seconds are optional, and the useful precision may vary depending on the data source.

=item B<format_timestamp DATETIME>

Converts the L<DateTime> object DATETIME into the appropriate format for the timestamp (month, day, year, hour, minute, second, fractional seconds) data type of the current data source.  Fractional seconds are optional, and the useful precision may vary depending on the data source.

=item B<parse_bitfield BITS [, SIZE]>

Parse BITS and return a corresponding L<Bit::Vector> object.  If SIZE is not passed, then it defaults to the number of bits in the parsed bit string.

If BITS is a string of "1"s and "0"s or matches C</^B'[10]+'$/>, then the "1"s and "0"s are parsed as a binary string.

If BITS is a string of numbers, at least one of which is in the range 2-9, it is assumed to be a decimal (base 10) number and is converted to a bitfield as such.

If BITS matches any of these regular expressions:

    /^0x/
    /^X'.*'$/
    /^[0-9a-f]+$/

it is assumed to be a hexadecimal number and is converted to a bitfield as such.

Otherwise, undef is returned.

=item B<parse_boolean STRING>

Parse STRING and return a boolean value of 1 or 0.  STRING should be formatted according to the data source's native "boolean" data type.  The default implementation accepts 't', 'true', 'y', 'yes', and '1' values for true, and 'f', 'false', 'n', 'no', and '0' values for false.

If STRING is a valid boolean keyword (according to L<validate_boolean_keyword|/validate_boolean_keyword>) or if it looks like a function call (matches C</^\w+\(.*\)$/>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "boolean" value.

=item B<parse_date STRING>

Parse STRING and return a L<DateTime> object.  STRING should be formatted according to the data source's native "date" (month, day, year) data type.

If STRING is a valid date keyword (according to L<validate_date_keyword|/validate_date_keyword>) or if it looks like a function call (matches C</^\w+\(.*\)$/>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "date" value.

=item B<parse_datetime STRING>

Parse STRING and return a L<DateTime> object.  STRING should be formatted according to the data source's native "datetime" (month, day, year, hour, minute, second) data type.

If STRING is a valid datetime keyword (according to L<validate_datetime_keyword|/validate_datetime_keyword>) or if it looks like a function call (matches C</^\w+\(.*\)$/>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "datetime" value.

=item B<parse_interval STRING [, MODE]>

Parse STRING and return a L<DateTime::Duration> object.  STRING should be formatted according to the data source's native "interval" (years, months, days, hours, minutes, seconds) data type.

If STRING is a L<DateTime::Duration> object, a valid interval keyword (according to L<validate_interval_keyword|/validate_interval_keyword>), or if it looks like a function call (matches C</^\w+\(.*\)$/>) then it is returned unmodified.  Otherwise, undef is returned if STRING could not be parsed as a valid "interval" value.

This optional MODE argyment determines how math is done on duration objects.  If defined, the C<end_of_month> setting for each L<DateTime::Duration> object created by this column will have its mode set to MODE.  Otherwise, the C<end_of_month> parameter will not be passed to the L<DateTime::Duration> constructor.

Valid modes are C<wrap>, C<limit>, and C<preserve>.  See the documentation for L<DateTime::Duration> for a full explanation.

=item B<parse_time STRING>

Parse STRING and return a L<Time::Clock> object.  STRING should be formatted according to the data source's native "time" (hour, minute, second, fractional seconds) data type.

If STRING is a valid time keyword (according to L<validate_time_keyword|/validate_time_keyword>) or if it looks like a function call (matches C</^\w+\(.*\)$/>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "time" value.

=item B<parse_timestamp STRING>

Parse STRING and return a L<DateTime> object.  STRING should be formatted according to the data source's native "timestamp" (month, day, year, hour, minute, second, fractional seconds) data type.  Fractional seconds are optional, and the acceptable precision may vary depending on the data source.  

If STRING is a valid timestamp keyword (according to L<validate_timestamp_keyword|/validate_timestamp_keyword>) or if it looks like a function call (matches C</^\w+\(.*\)$/>) it is returned unmodified.  Returns undef if STRING could not be parsed as a valid "timestamp" value.

=item B<validate_boolean_keyword STRING>

Returns true if STRING is a valid keyword for the "boolean" data type of the current data source, false otherwise.  The default implementation accepts the values "TRUE" and "FALSE".

=item B<validate_date_keyword STRING>

Returns true if STRING is a valid keyword for the "date" (month, day, year) data type of the current data source, false otherwise.  The default implementation always returns false.

=item B<validate_datetime_keyword STRING>

Returns true if STRING is a valid keyword for the "datetime" (month, day, year, hour, minute, second) data type of the current data source, false otherwise.  The default implementation always returns false.

=item B<validate_interval_keyword STRING>

Returns true if STRING is a valid keyword for the "interval" (years, months, days, hours, minutes, seconds) data type of the current data source, false otherwise.  The default implementation always returns false.

=item B<validate_time_keyword STRING>

Returns true if STRING is a valid keyword for the "time" (hour, minute, second, fractional seconds) data type of the current data source, false otherwise.  The default implementation always returns false.

=item B<validate_timestamp_keyword STRING>

Returns true if STRING is a valid keyword for the "timestamp" (month, day, year, hour, minute, second, fractional seconds) data type of the current data source, false otherwise.  The default implementation always returns false.

=back

=head1 DEVELOPMENT POLICY

The L<Rose development policy|Rose/"DEVELOPMENT POLICY"> applies to this, and all C<Rose::*> modules.  Please install L<Rose> from CPAN and then run "C<perldoc Rose>" for more information.

=head1 SUPPORT

Any L<Rose::DB> questions or problems can be posted to the L<Rose::DB::Object> mailing list.  (If the volume ever gets high enough, I'll create a separate list for L<Rose::DB>, but it isn't an issue right now.)  To subscribe to the list or view the archives, go here:

L<http://lists.sourceforge.net/lists/listinfo/rose-db-object>

Although the mailing list is the preferred support mechanism, you can also email the author (see below) or file bugs using the CPAN bug tracking system:

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-DB>

=head1 CONTRIBUTORS

Ron Savage

Lucian Dragus

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
