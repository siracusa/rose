package Rose::DB::Object::Metadata::Auto::SQLite;

use strict;

use Carp();

use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.53';

sub auto_generate_columns
{
  my($self) = shift;

  my($class, %columns);

  eval
  {
    my $col_info = ($self->_get_info)[0] || [];

    die "No columns found"  unless(@$col_info);

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;
  
    foreach my $info (@$col_info)
    {
      $db->refine_dbi_column_info($info);

      $columns{$info->{'COLUMN_NAME'}} = 
        $self->auto_generate_column($info->{'COLUMN_NAME'}, $info);
    }
  };

  if($@ || !keys %columns)
  {
    no warnings; # undef strings okay
    Carp::croak "Could not auto-generate columns for class $class, table '",
                $self->table, "' - $@";
  }

  $self->auto_alias_columns(values %columns);

  return wantarray ? values %columns : \%columns;
}

sub auto_retrieve_primary_key_column_names
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_retrieve_primary_key_column_names() in void context";
  }

  my($class, $col_info, $pk_columns);

  eval
  {
    $pk_columns = ($self->_get_info)[1] || [];
  };

  if($@ || !@$pk_columns)
  {
    $@ = 'no primary key coumns found'  unless(defined $@);
    Carp::croak "Could not auto-retrieve primary key columns for class $class - $@";
  }

  return wantarray ? @$pk_columns : $pk_columns;
}

my $UK_Num = 1;

sub auto_generate_unique_keys
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_unique_keys() in void context";
  }

  my($class, %unique_keys);

  eval
  {
    my $uk_info = ($self->_get_info)[2] || [];

    foreach my $info (@$uk_info)
    {
      my $uk_name = 'unique_key_' . $UK_Num++;

      my $uk = $unique_keys{$uk_name} = 
        Rose::DB::Object::Metadata::UniqueKey->new(name   => $uk_name,
                                                   parent => $self);

      foreach my $column (@$info)
      {
        $uk->add_column($column);
      }

      $unique_keys{$uk_name} = $uk;
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $@";
  }

  # This sort order is part of the API, and is essential to make the
  # test suite work.
  my @uk = map { $unique_keys{$_} } sort map { lc } keys(%unique_keys);

  return wantarray ? @uk : \@uk;
}

sub auto_generate_foreign_keys
{
  my($self, %args) = @_;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_foreign_keys() in void context";
  }

  my $no_warnings = $args{'no_warnings'};

  my($class, @foreign_keys, $total_fks);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;
    my $table_quoted = $db->quote_table_name($self->table);

    my $sth = $dbh->prepare("PRAGMA foreign_key_list($table_quoted)");
    $sth->execute;

    my %fk_info;

    while(my $row = $sth->fetchrow_hashref)
    {
      push(@{$fk_info{$row->{'id'}}}, $row);
    }

    my $cm = $self->convention_manager;
    
    FK: foreach my $id (sort { $a <=> $b } keys(%fk_info))
    {
      my $col_info = $fk_info{$id};
      
      my $foreign_table = $col_info->[0]{'table'};
      
      my $foreign_class = $self->class_for(table => $foreign_table);

      unless($foreign_class)
      {
        # Add deferred task
        $self->add_deferred_task(
        {
          class  => $self->class, 
          method => 'auto_init_foreign_keys',
          args   => \%args,

          code => sub
          {
            $self->auto_init_foreign_keys(%args);
            $self->make_foreign_key_methods(%args, preserve_existing => 1);
          },

          check => sub
          {
            my $fks = $self->foreign_keys;
            return @$fks == $total_fks ? 1 : 0;
          }
        });

        unless($no_warnings || $self->allow_auto_initialization)
        {
          no warnings; # Allow undef coercion to empty string
          warn "No Rose::DB::Object-derived class found for table ",
               "'$foreign_table'";
        }

        $total_fks++;
        next FK;
      }

      my(@local_columns, @foreign_columns);

      foreach my $item (@$col_info)
      {
        push(@local_columns, $item->{'from'});
        push(@foreign_columns, $item->{'to'});
      }

      unless(@local_columns > 0 && @local_columns == @foreign_columns)
      {
        die "Failed to extract a matched set of columns from ",
            'PRAGMA foreign_key_list(', $self->table, ')';
      }

      my %key_columns;
      @key_columns{@local_columns} = @foreign_columns;

      my $key_name = $cm->auto_foreign_key_name($foreign_class);

      my $fk = 
        Rose::DB::Object::Metadata::ForeignKey->new(
          name        => $key_name,
          class       => $foreign_class,
          key_columns => \%key_columns);

      push(@foreign_keys, $fk);
      $total_fks++;
    }

    # This step is important!  It ensures that foreign keys will be created
    # in a deterministic order, which in turn allows the "auto-naming" of
    # foreign keys to work in a predictible manner.  This exact sort order
    # (lowercase table name comparisons) is part of the API for foreign
    # key auto generation.
    @foreign_keys = 
      sort { lc $a->class->meta->table cmp lc $b->class->meta->table } 
      @foreign_keys;

    foreach my $fk (@foreign_keys)
    {
      my $name = $self->foreign_key_name_generator->($self, $fk);

      unless(defined $name && $name =~ /^\w+$/)
      {
        die "Missing or invalid key name '$name' for foreign key ",
            "generated in $class for ", $fk->class;
      }

      $fk->name($name);
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-generate foreign keys for class $class - $@";
  }

  @foreign_keys = sort { lc $a->name cmp lc $b->name } @foreign_keys;

  return wantarray ? @foreign_keys : \@foreign_keys;
}

sub _get_info
{
  my($self) = shift;

  my $db  = $self->db;
  my $dbh = $db->dbh or die $db->error;

  my $table_unquoted = $db->unquote_table_name($self->table);

  my $sth = $dbh->prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?");
  my $sql;

  $sth->execute($table_unquoted);
  $sth->bind_columns(\$sql);
  $sth->fetch;
  $sth->finish;

  return _info_from_sql($sql);
}

## Yay!  A Giant Wad o' Regexes "parser"!  Yeah, this is lame, but I really
## don't want to load an actual parser, or even a regex lib or helper...

our $Paren_Depth   = 15;
our $Nested_Parens = '\(' . '([^()]|\(' x $Paren_Depth . '[^()]*' . '\))*' x $Paren_Depth . '\)';

# This doesn't seem to work...
#$Nested_Parens = qr{\( (?: (?> [^()]+ ) | (??{ $Nested_Parens }) )* \)}x;

our $Quoted =   
  qr{(?: ' (?: [^'] | '' )+ '
     | " (?: [^"] | "" )+ "
     | ` (?: [^`] | `` )+ `)}six;

our $Name = qr{(?: $Quoted | \w+ )}six;

our $Type = 
  qr{\w+ (?: \s* \( \s* \d+ \s* (?: , \s* \d+ \s*)? \) )?}six;

our $Conflict_Algorithm = 
  qr{(?: ROLLBACK | ABORT | FAIL | IGNORE | REPLACE )}six;

our $Conflict_Clause =
  qr{(?: ON \s+ CONFLICT \s+ $Conflict_Algorithm )}six;

our $Sort_Order = 
  qr{(?: COLLATE \s+ \S+ \s+)? (?:ASC | DESC)}six;

our $Column_Constraint = 
  qr{(?: NOT \s+ NULL (?: \s+ $Conflict_Clause)?
     | PRIMARY \s+ KEY (?: \s+ $Sort_Order)? (?: \s+ $Conflict_Clause)? (?: \s+ AUTOINCREMENT)? 
     | UNIQUE (?: \s+ $Conflict_Clause)? 
     | CHECK \s* $Nested_Parens (?: \s+ $Conflict_Clause)?
     | REFERENCES \s+ $Name \s* \( \s* $Name \s* \)
     | DEFAULT \s+ (?: $Name | \w+ \s* $Nested_Parens | [^,)]+ )
     | COLLATE \s+ \S+)}six;

our $Table_Constraint =
  qr{(?: (?: PRIMARY \s+ KEY | UNIQUE | CHECK ) \s* $Nested_Parens 
     | FOREIGN \s+ KEY \s+ (?: $Name \s+ )? $Nested_Parens \s+ REFERENCES \s+ $Name \s+ $Nested_Parens )}six;

our $Column_Def =
  qr{($Name) (?:\s+ ($Type))? ( (?: \s+ (?:CONSTRAINT \s+ $Name \s+)? $Column_Constraint )* )}six;

# SQLite allows C comments to be unterminated if they're at the end of the 
# input stream.  Crazy, but true: http://www.sqlite.org/lang_comment.html
our $C_Comment_Cont = qr{/\*.*$}six;
our $C_Comment      = qr{/\*[^*]*\*+(?:[^/*][^*]*\*+)*/}six;
our $SQL_Comment    = qr{--[^\r\n]*(\r?\n)}six;
our $Comment        = qr{($Quoted)|($C_Comment|$SQL_Comment|$C_Comment_Cont)}six;

# These constants are from the DBI documentation.  Is there somewhere 
# I can load these from?
use constant SQL_NO_NULLS => 0;
use constant SQL_NULLABLE => 1;

sub _info_from_sql
{
  my $sql = shift;
  
  my(@col_info, @pk_columns, @uk_info);

  my($new_sql, $pos);

  # Remove comments
  while($sql =~ /\G((.*?)$Comment)/sgix)
  {
    $pos = pos($sql);

    if(defined $4) # caught comment
    {
      no warnings 'uninitialized';
      $new_sql .= "$2$3";
    }
    else
    {
      $new_sql .= $1;
    }
  }

  $sql = $new_sql . substr($sql, $pos) if(defined $new_sql);

  # Remove the start and end
  $sql =~ s/^\s* CREATE \s+ (?:TEMP(?:ORARY)? \s+)? TABLE \s+ $Name \s*\(\s*//sgix;
  $sql =~ s/\s*\)\s*$//six;

  # Remove leading space from lines
  $sql =~ s/^\s+//mg;

  my $i = 1;

  # Column defintiions
  while($sql =~ s/^$Column_Def (?:\s*,\s*|\s*$)//six)
  {
    my $col_name    = $1;
    my $col_type    = $2 || 'scalar';
    my $constraints = $3;

    unless(defined $col_name)
    {
      Carp::croak "Could not extract column name from SQL: $sql";
    }

    my %col_info =
    (
      COLUMN_NAME      => $col_name,
      TYPE_NAME        => $col_type,
      ORDINAL_POSITION => $i++,
    );

    if($col_type =~ /^(\w+) \s* \( \s* (\d+) \s* \)$/x)
    {
      $col_info{'TYPE_NAME'}         = $1;
      $col_info{'COLUMN_SIZE'}       = $2;
      $col_info{'CHAR_OCTET_LENGTH'} = $2;
    }
    elsif($col_type =~ /^\s* (\w+) \s* \( \s* (\d+) \s* , \s* (\d+) \s* \) \s*$/x)
    {
      $col_info{'TYPE_NAME'}      = $1;
      $col_info{'DECIMAL_DIGITS'} = $2;
      $col_info{'COLUMN_SIZE'}    = $3;
    }

    while($constraints =~ s/^\s* (?:CONSTRAINT \s+ $Name \s+)? ($Column_Constraint) \s*//six)
    {
      local $_ = $1;

      if(/^DEFAULT \s+ ( $Name | \w+ \s* $Nested_Parens | [^,)]+ )/six)
      {
        $col_info{'COLUMN_DEF'} = _unquote_name($1);
      }
      elsif(/^PRIMARY \s+ KEY \b/six)
      {
        push(@pk_columns, $col_name)
      }
      elsif(/^NOT \s+ NULL \b/six)
      {
        $col_info{'NULLABLE'} = SQL_NO_NULLS;
      }
    }

    $col_info{'NULLABLE'} = SQL_NULLABLE  unless(defined $col_info{'NULLABLE'});

    push(@col_info, \%col_info);
  }

  while($sql =~ s/^($Table_Constraint) (?:\s*,\s*|\s*$)//six)
  {
    my $constraint = $1;

    if($constraint =~ /^\s* PRIMARY \s+ KEY \s* ($Nested_Parens)/six)
    {
      @pk_columns = ();

      my $columns = $1;
      $columns =~ s/^\(\s*//;
      $columns =~ s/\s*\)\s*$//;
      
      while($columns =~ s/^\s* ($Name) (?:\s*,\s*|\s*$)//six)
      {
        push(@pk_columns, _unquote_name($1));
      }
    }
    elsif($constraint =~ /^\s* UNIQUE \s* ($Nested_Parens)/six)
    {
      my $columns = $1;
      $columns =~ s/^\(\s*//;
      $columns =~ s/\s*\)\s*$//;
      
      my @uk_columns;

      while($columns =~ s/^\s* ($Name) (?:\s*,\s*|\s*$)//six)
      {
        push(@uk_columns, _unquote_name($1));
      }
      
      push(@uk_info, \@uk_columns);
    }
  }
$DB::single = 1;
  return(\@col_info, \@pk_columns, \@uk_info);
}

sub _unquote_name
{
  my $name = shift;

  if($name =~ s/^(['`"]) ( (?: [^\1]+ | \1\1 )+ ) \1 $/$2/six)
  {
    my $q = $1;
    $name =~ s/$q$q/$q/g;
  }

  return $name;
}

1;
