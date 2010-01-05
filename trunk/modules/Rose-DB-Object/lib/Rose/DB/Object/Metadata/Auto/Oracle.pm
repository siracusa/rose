package Rose::DB::Object::Metadata::Auto::Oracle;

use strict;

use Carp();

use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.784';

sub auto_init_primary_key_columns
{
  my($self) = shift;

  $self->SUPER::auto_init_primary_key_columns(@_);

  my $cm = $self->convention_manager;

  return  unless($cm->no_auto_sequences);

  my @sequences;
  my $table = $self->table;

  # Auto-add expected sequence for what look like single-column
  # non-null "serial" columns.
  my @pk_columns = $self->primary_key_columns;
  
  if(@pk_columns == 1)
  {
    foreach my $name (@pk_columns)
    {
      my $column = $self->column($name) or next;
      next unless ($column->not_null);
      push(@sequences, $cm->auto_primary_key_column_sequence_name($table, $name));
    }

    $self->primary_key_sequence_names(@sequences)  if(@sequences);
  }

  return;
}

use constant UNIQUE_INDEX_SQL => <<'EOF';
select ai.index_name FROM ALL_INDEXES ai, ALL_CONSTRAINTS ac 
WHERE ai.index_name = ac.constraint_name AND 
      ac.constraint_type <> 'P' AND 
      ai.uniqueness = 'UNIQUE' AND ai.table_name = ? AND 
      ai.table_owner = ?
EOF

use constant UNIQUE_INDEX_COLUMNS_SQL_STUB => <<'EOF';
select column_name FROM ALL_IND_COLUMNS WHERE index_name = ? ORDER BY column_position
EOF

sub auto_generate_unique_keys
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_unique_keys() in void context";
  }

  my($class, @unique_keys, $error);

  TRY:
  {
    local $@;

    eval
    {
      $class = $self->class or die "Missing class!";

      my $db  = $self->db;
      my $dbh = $db->dbh or die $db->error;

      local $dbh->{'FetchHashKeyName'} = 'NAME';

      my $schema = $self->select_schema($db);
      $schema = $db->default_implicit_schema  unless(defined $schema);
      $schema = uc $schema  if(defined $schema);

      my $table = uc $self->table;

      my $key_name;

      my $sth = $dbh->prepare(UNIQUE_INDEX_SQL);

      $sth->execute($table, $schema);
      $sth->bind_columns(\$key_name);

      while($sth->fetch)
      {
        my $uk = Rose::DB::Object::Metadata::UniqueKey->new(name   => $key_name,
                                                            parent => $self);

        my $col_sth = $dbh->prepare(UNIQUE_INDEX_COLUMNS_SQL_STUB);

        my($column, @columns);

        $col_sth->execute($key_name);
        $col_sth->bind_columns(\$column);

        while($col_sth->fetch)
        {
          push(@columns, $column);
        }

        unless(@columns)
        {
          die "No columns found for key $key_name";
        }

        $uk->columns(\@columns);

        push(@unique_keys, $uk);
      }
    };

    $error = $@;
  }

  if($error)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $error";
  }

  # This sort order is part of the API, and is essential to make the
  # test suite work.
  @unique_keys = sort { lc $a->name cmp lc $b->name } @unique_keys;

  return wantarray ? @unique_keys : \@unique_keys;
}

1;
