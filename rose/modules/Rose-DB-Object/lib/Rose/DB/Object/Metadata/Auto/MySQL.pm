package Rose::DB::Object::Metadata::Auto::MySQL;

use strict;

use Carp();

use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.53';

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
$DB::single = 1;
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

    my $q = $dbh->get_info(29); # quote character

    my $sth = $dbh->prepare("SHOW TABLE STATUS FROM `$db_name` LIKE ?");
    $sth->execute($self->table);

    # This happens when the table has no foreign keys
    return  unless(defined $sth);

    my $cm = $self->convention_manager;

    FK: while(my $row = $sth->fetchrow_hashref)
    {
      # The Comment column contains a text description of foreign keys that
      # we have to parse.  See, this is why people hate MySQL.
      #
      # The comment looks like this (s/\n/ /g):
      #
      # InnoDB free: 4096 kB;
      # (`fother_id2`) REFER `test/rose_db_object_other2`(`id2`) 
      # ON DELETE NO ACTION ON UPDATE SET NULL;
      # (`fother_id3`) REFER `test/rose_db_object_other3`(`id3`);
      # (`fother_id4`) REFER `test/rose_db_object_other4`(`id4`);
      # (`fk1` `fk2` `fk3`) REFER `test/rose_db_object_other`(`k1` `k2` `k3`)

      for(my $comment = $row->{'Comment'})
      {
        s/^InnoDB free:.+?; *//i;

        FK: while(s{\( ((?:`(?:[^`]|``)+` \s*)+) \) \s+ REFER \s* 
                    `((?:[^`]|``)+) / ((?:[^`]|``)+) ` 
                    \( ((?:`(?:[^`]|``)+` \s*)+) \) 
                    (?: \s+ ON \s+ (?: DELETE | UPDATE) \s+
                      (?: RESTRICT | CASCADE | SET \s+ NULL | NO \s+ ACTION)
                    )* (?:; \s* | \s* $)}{}six)
        {
          my $local_columns   = $1;
          my $foreign_db      = $2;
          my $foreign_table   = $3;
          my $foreign_columns = $4;

          next  unless(lc $foreign_db eq $db_name);

          my @local_columns   = map { s/^`//; s/`$//; $_ } split(' ', $local_columns);
          my @foreign_columns = map { s/^`//; s/`$//; $_ } split(' ', $foreign_columns);

          unless(@local_columns > 0 && @local_columns == @foreign_columns)
          {
            die "Failed to parse MySQL foreign key Comment ",
                "'$row->{'Comment'}' returned by the query '",
                "SHOW TABLE STATUS FROM `$db_name` LIKE '", 
                $self->table, "'";
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

          my $key_name = $cm->auto_foreign_key_name($foreign_class);

          my $fk = 
            Rose::DB::Object::Metadata::ForeignKey->new(
              name        => $key_name,
              class       => $foreign_class,
              key_columns => \%key_columns);

          push(@foreign_keys, $fk);
          $total_fks++;
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

1;
