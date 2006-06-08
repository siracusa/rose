package Rose::DB::Object::Metadata::Auto::SQLite;

use strict;

use Carp();

use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.73';

sub auto_generate_columns
{
  my($self) = shift;

  my($class, %columns);

  eval
  {
    my $col_info = ($self->_table_info)[0] || [];

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
    my $uk_info = ($self->_table_info)[2] || [];

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

sub _table_info
{
  my($self) = shift;

  # XXX: I'm in the process of moving all introspection to Rose::DB.
  # XXX: _table_info is an undocumented method of Rose::DB::SQLite
  $self->db->_table_info($self->table);
}

1;
