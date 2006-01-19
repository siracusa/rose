package Rose::DB::Object::Metadata::Auto::MySQL;

use strict;

use Carp();

use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.64';

sub auto_retrieve_primary_key_column_names
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_retrieve_primary_key_column_names() in void context";
  }

  my($class, @columns);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $sth = $dbh->prepare('SHOW INDEX FROM ' . $self->fq_table_sql($db));
    $sth->execute;

    while(my $row = $sth->fetchrow_hashref)
    {
      next  unless($row->{'Key_name'} eq 'PRIMARY');
      push(@columns, $row->{'Column_name'});
    }
  };

  if($@ || !@columns)
  {
    $@ = 'no primary key coumns found'  unless(defined $@);
    Carp::croak "Could not auto-retrieve primary key columns for class $class - $@";
  }

  return wantarray ? @columns : \@columns;
}

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
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $sth = $dbh->prepare('SHOW INDEX FROM ' . $self->fq_table_sql($db));
    $sth->execute;

    while(my $row = $sth->fetchrow_hashref)
    {
      next  if($row->{'Non_unique'} || $row->{'Key_name'} eq 'PRIMARY');

      my $uk = $unique_keys{$row->{'Key_name'}} ||= 
        Rose::DB::Object::Metadata::UniqueKey->new(name   => $row->{'Key_name'}, 
                                                   parent => $self);

      $uk->add_column($row->{'Column_name'});
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $@";
  }

  # This sort order is part of the API, and is essential to make the
  # test suite work.
  no warnings 'uninitialized';
  my @uk = map { $unique_keys{$_} } sort { lc $a <=> lc $b } keys(%unique_keys);

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
    my $db_name = $db->database;

    my $cm = $self->convention_manager;

    my $information_schema_ok = 0;

    # Try information_schema if using MySQL >= 5.0.6
    if($db->database_version >= 5_000_006)
    {
      eval
      {
        local $dbh->{'PrintError'} = 0;

        my $sth = $dbh->prepare(<<"EOF");
SELECT
  CONSTRAINT_CATALOG,
  CONSTRAINT_SCHEMA,
  CONSTRAINT_NAME,
  TABLE_CATALOG,
  TABLE_SCHEMA,
  TABLE_NAME,
  COLUMN_NAME,
  REFERENCED_TABLE_SCHEMA,
  REFERENCED_TABLE_NAME,
  REFERENCED_COLUMN_NAME
FROM
  INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE 
  REFERENCED_TABLE_NAME IS NOT NULL AND
  TABLE_SCHEMA = ? AND TABLE_NAME = ?
ORDER BY
  REFERENCED_TABLE_SCHEMA, REFERENCED_TABLE_NAME
EOF
        $sth->execute($db_name, $self->table);

        my($constraint_catalog, $constraint_schema, $constraint_name,
           $table_catalog, $table_schema, $table_name, $local_column,
           $foreign_schema, $foreign_table, $foreign_column);

        $sth->bind_columns(\($constraint_catalog, $constraint_schema, $constraint_name,
                             $table_catalog, $table_schema, $table_name, $local_column,
                             $foreign_schema, $foreign_table, $foreign_column));
        my %fk_info;

        while($sth->fetch)
        {
          # No cross-database foreign keys in MySQL for now...
          next  unless(!defined $foreign_schema || lc $foreign_schema eq lc $db_name);

          my $info = $fk_info{$foreign_table} ||= {};

          push(@{$info->{'local_columns'}}, $local_column);
          push(@{$info->{'foreign_columns'}}, $foreign_column);
        }

        FK: while(my($foreign_table, $info) = each %fk_info)
        {
          my @local_columns   = @{$info->{'local_columns'}};
          my @foreign_columns = @{$info->{'foreign_columns'}};

          unless(@local_columns > 0 && @local_columns == @foreign_columns)
          {
            die "Failed to extrat foreign key information from ",
                "information_schema for table '", $self->table, "' ",
                " in database '$db_name'";
          }

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

          my %key_columns;
          @key_columns{@local_columns} = @foreign_columns;

          my $fk = 
            Rose::DB::Object::Metadata::ForeignKey->new(
              class       => $foreign_class,
              key_columns => \%key_columns);

          push(@foreign_keys, $fk);
          $total_fks++;
        }

        $information_schema_ok = 1;
      };
    }

    # Fall back to the crappy method...
    unless($information_schema_ok)
    {
      #my $q = $dbh->get_info(29); # quote character

      my $sth = $dbh->prepare("SHOW CREATE TABLE `$db_name`.`" . $self->table . '`');
      $sth->execute;

      # This happens when the table has no foreign keys
      return  unless(defined $sth);

      FK: while(my $row = $sth->fetchrow_hashref)
      {
        # The Create Table column contains a text description of foreign keys 
        # that we have to parse.  See, this is why people hate MySQL.
        #
        # The value looks like this (s/\n/ /g):
        #
        # CONSTRAINT `products_ibfk_1` FOREIGN KEY (`vendor_id`) 
        # REFERENCES `vendors` (`id`) ON DELETE NO ACTION ON UPDATE SET NULL,
        # CONSTRAINT `products_ibfk_1` FOREIGN KEY (`vendor_id`) 
        # REFERENCES `dbname`.`vendors` (`id`) ON DELETE NO ACTION ON UPDATE SET NULL,
        # CONSTRAINT `rose_db_object_test_ibfk_4` FOREIGN KEY (`fk1`, `fk2`, `fk3`)
        # REFERENCES `rose_db_object_other` (`k1`, `k2`, `k3`)

        for(my $sql = $row->{'Create Table'})
        {
          s/^.+?,\n\s*(?=CONSTRAINT)//si;

          # XXX: This is not bullet-proof
          FK: while(s{^CONSTRAINT \s+ 
                      `((?:[^`]|``)+)` \s+                  # constraint name
                      FOREIGN \s+ KEY \s+
                      \( ((?:`(?:[^`]|``)+`,? \s*)+) \) \s+ # local columns
                      REFERENCES \s* 
                      (?: `((?:[^`]|``)+)` \. )?            # foreign db
                      `((?:[^`]|``)+)` \s+                  # foreign table
                      \( ((?:`(?:[^`]|``)+`,? \s*)+) \)     # foreign columns
                      (?: \s+ ON \s+ (?: DELETE | UPDATE) \s+
                        (?: RESTRICT | CASCADE | SET \s+ NULL | NO \s+ ACTION)
                      )* (?:, \s* | \s* \))}{}six)
          {
            my $constraint_name = $1;
            my $local_columns   = $2;
            my $foreign_db      = $3;
            my $foreign_table   = $4;
            my $foreign_columns = $5;

            # No cross-database foreign keys in MySQL for now...
            next  unless(!defined $foreign_db || lc $foreign_db eq $db_name);

            # XXX: This is not bullet-proof
            my @local_columns   = map { s/^`//; s/`$//; s/``/`/g; $_ } split(/,? /, $local_columns);
            my @foreign_columns = map { s/^`//; s/`$//; s/``/`/g; $_ } split(/,? /, $foreign_columns);

            unless(@local_columns > 0 && @local_columns == @foreign_columns)
            {
              die "Failed to parse MySQL table definition ",
                  "'$row->{'Create Table'}' returned by the query '",
                  "SHOW CREATE TABLE `$db_name`.`" . $self->table . '`';
            }

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

            my %key_columns;
            @key_columns{@local_columns} = @foreign_columns;

            my $fk = 
              Rose::DB::Object::Metadata::ForeignKey->new(
                class       => $foreign_class,
                key_columns => \%key_columns);

            push(@foreign_keys, $fk);
            $total_fks++;
          }
        }
      }
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
      my $key_name = 
        $cm->auto_foreign_key_name($fk->class) ||
        $self->foreign_key_name_generator->($self, $fk);

      unless(defined $key_name && $key_name =~ /^\w+$/)
      {
        die "Missing or invalid key name '$key_name' for foreign key ",
            "generated in $class for ", $fk->class;
      }

      $fk->name($key_name);
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-generate foreign keys for class $class - $@";
  }

  @foreign_keys = sort { lc $a->name cmp lc $b->name } @foreign_keys;

  return wantarray ? @foreign_keys : \@foreign_keys;
}

1;
