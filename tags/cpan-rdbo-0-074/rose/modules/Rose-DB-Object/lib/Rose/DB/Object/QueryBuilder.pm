package Rose::DB::Object::QueryBuilder;

use strict;

use Carp();

use Rose::DB::Object::Constants qw(STATE_SAVING);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(build_select build_where_clause);

our $VERSION = '0.041';

our $Debug = 0;

my %OP_MAP = 
(
  regex      => 'REGEXP',
  regexp     => 'REGEXP',
  like       => 'LIKE',
  ilike      => 'ILIKE',
  rlike      => 'RLIKE',
  lt         => '<',
  le         => '<=',
  ge         => '>=',
  gt         => '>',
  ne         => '<>',
  eq         => '=',
  in_set     => 'ANY IN',
  any_in_set => 'ANY IN',
  all_in_set => 'ALL IN',
);

@OP_MAP{map { $_ . '_sql' } keys %OP_MAP} = values(%OP_MAP);

sub build_where_clause { build_select(@_, where_only => 1) }

sub build_select
{
  my(%args) = @_;

  my $dbh         = $args{'dbh'};
  my $tables      = $args{'tables'} || Carp::croak "Missing 'tables' argument";
  my $logic       = delete $args{'logic'} || 'AND';
  my $columns     = $args{'columns'};  
  my $query_arg   = delete $args{'query'};
  my $sort_by     = delete $args{'sort_by'};
  my $group_by    = delete $args{'group_by'};
  my $limit       = delete $args{'limit'};
  my $select      = $args{'select'};
  my $where_only  = delete $args{'where_only'};
  my $clauses_arg = delete $args{'clauses'};  
  my $pretty      = exists $args{'pretty'} ? $args{'pretty'} : $Debug;
  my $joins       = $args{'joins'};

  $args{'_depth'}++;

  unless($args{'dbh'})
  {
    if($args{'db'})
    {
      $dbh = $args{'db'}->dbh || Carp::croak "Missing 'dbh' argument and ",
        "could not retreive one from the 'db' agument - ", $args{'db'}->error;
    }
    else { Carp::croak "Missing 'dbh' argument" }
  }

  my $do_bind = wantarray;

  my(@bind, @clauses);

  my %query;

  if($query_arg)
  {
    for(my $i = 0; $i < $#$query_arg; $i += 2)
    {
      if($query_arg->[$i] =~ /^(?:and|or)$/i)
      {
        my($sql, $bind);

        if($do_bind)
        {
          ($sql, $bind) =
            build_select(%args, 
                         where_only => 1,
                         query => $query_arg->[$i + 1],
                         logic => uc $query_arg->[$i]);

          push(@bind, @$bind);
        }
        else
        {
          $sql =
            build_select(%args, 
                         where_only => 1,
                         query => $query_arg->[$i + 1],
                         logic => uc $query_arg->[$i]);
        }

        if($pretty)
        {
          my $pad     = '  ' x $args{'_depth'};
          my $sub_pad = '  ' x ($args{'_depth'} - 1);

          for($sql)
          {
            s/\A //;
            s/^ +$//g;
            s/\s*\Z//;
          }

          push(@clauses, "(\n" . $sql . "\n" . "$pad)");
        }
        else
        {
          push(@clauses, "($sql)");
        }
      }
      else
      {
        push(@{$query{$query_arg->[$i]}}, $query_arg->[$i + 1]);
      }
    }
  }

  my $query_is_sql = $args{'query_is_sql'};

  $select   = join(', ', @$select)    if(ref $select);
  $sort_by  = join(', ', @$sort_by)   if(ref $sort_by);
  $group_by = join(', ', @$group_by)  if(ref $group_by);

  my($not, $op, @select_columns, %column_count);

  foreach my $table (@$tables)
  {
    next  unless($columns->{$table});

    foreach my $column (@{$columns->{$table}})
    {
      $column_count{$column}++;
    }
  }

  my $multi_table = @$tables > 1 ? 1 : 0;
  my $table_num = 1;

  my %proto; # prototype objects used for formatting values

  foreach my $table (@$tables)
  {
    my $table_alias = 't' . $table_num++;

    next  unless($columns->{$table});

    my($classes, $meta, $db, $obj_class, $obj_meta);

    unless($query_is_sql)
    {
      $classes = $args{'classes'} or 
        Carp::croak "Missing 'classes' arg which is required unless 'query_is_sql' is true";

      $meta = $args{'meta'} || {};

      $db = $args{'db'} or
        Carp::croak "Missing 'db' arg which is required unless 'query_is_sql' is true";

      $obj_class = $classes->{$table}
        or Carp::confess "No class name found for table '$table'";

      $obj_meta = $meta->{$obj_class} || $obj_class->meta
        or Carp::confess "No metadata found for class '$obj_class'";
    }

    foreach my $column (@{$columns->{$table}})
    {
      my $fq_column    = "$table.$column";
      my $short_column = "$table_alias.$column";

      my $method = $obj_meta ? $obj_meta->column_rw_method_name($column) : undef;

      push(@select_columns, $multi_table ? 
           "$short_column AS ${table_alias}_$column" : $column);

      foreach my $column_arg (map { ($_, "!$_") } ($column, $fq_column, $short_column, 
                              (defined $method && $method ne $column ? $method : ())))
      {
        next  unless(exists $query{$column_arg});

        $not = (index($column_arg, '!') == 0) ? 'NOT' : '';

        # Deflate/format values using prototype objects
        foreach my $val (@{$query{$column_arg}})
        {
          my $col_meta;

          unless($query_is_sql)
          {      
            my $obj;

            $col_meta = $obj_meta->column($column) || $obj_meta->method_column($column)
              or Carp::confess "Could not get column metadata object for '$column'";

            unless($obj = $proto{$obj_class})
            {
              $obj = $proto{$obj_class} = $obj_class->new(db => $db);
              $obj->{STATE_SAVING()} = 1;
            }

            my $get_method = $obj_meta->column_accessor_method_name($column)
              or Carp::confess "Missing accessor method for column '$column'";

            my $set_method = $obj_meta->column_mutator_method_name($column)
              or Carp::confess "Missing mutator method for column '$column'";

            my %tmp = ($column_arg => $val);
            _format_value($db, \%tmp, $column_arg, $obj, $col_meta, $get_method, $set_method, $val);
            $val = $tmp{$column_arg};
          }

          if($column_arg eq $column && $column_count{$column} > 1)
          {
            Carp::croak "Column '$column' is ambiguous; it appears in ",
                        "$column_count{$column} tables.  Use a fully-qualified ",
                        "column name instead (e.g., $fq_column or $short_column)";
          }

          my $sql_column = $multi_table ? $short_column : $column;

          if(ref($val))
          {
            push(@clauses, _build_clause($dbh, $sql_column, $op, $val, $not, 
                                         undef, $do_bind ? \@bind : undef,
                                         $db, $col_meta));
          }
          elsif(!defined $val)
          {
            push(@clauses, "$sql_column IS " . ($not ? "$not " : '') . 'NULL');
          }
          else
          {
            if($do_bind)
            {
              push(@clauses, ($not ? "$not(" : '') . "$sql_column = ?" . ($not ? ')' : ''));
              push(@bind, $val);
            }
            else
            {
              push(@clauses, ($not ? "$not(" : '') . "$sql_column = " . $dbh->quote($val) . ($not ? ')' : ''));
            }
          }
        }
      }
    }
  }

  if($clauses_arg)
  {
    push(@clauses, @$clauses_arg);
  }

  my $where;

  if($pretty)
  {
    my $pad = '  ' x $args{'_depth'};
    $where = join(" $logic\n", map { "$pad$_" } @clauses);
  }
  else
  {
    $where = join(" $logic\n", map { "  $_" } @clauses);
  }

  my $qs;

  my $use_prefix_limit = $dbh->{'Driver'}{'Name'} eq 'Informix' ? 1 : 0;

  if(!$where_only)
  {
    my $tables_sql;

    # XXX: Undocumented "joins" parameter is an array indexed by table
    # alias number.  Each value is a hashref that contains a key 'type'
    # that contains the join type SQL, and 'conditions' that contains a
    # ref to an array of join conditions SQL.
    #
    # If this parameter is passed, then every table except t1 that has 
    # a join type and condition will be joined with an explicit JOIN
    # statement.  Otherwise, an inplicit inner join willbe used.
    if($joins && @$joins)
    {
      my $i = 1;
      my($primary_table, @normal_tables, @joined_tables);

      foreach my $table (@$tables)
      {
        # Main table gets treated specially
        if($i == 1)
        {
          $primary_table = "  $table t$i";
          $i++;
          next;
        }
        elsif(!$joins->[$i])
        {
          push(@normal_tables, "  $table t$i");
          $i++;
          next;
        }

        Carp::croak "Missing join type for table '$table'"
          unless($joins->[$i]{'type'});

        Carp::croak "Missing join conditions for table '$table'"
          unless($joins->[$i]{'conditions'});

        push(@joined_tables, 
             "  $joins->[$i]{'type'} $table t$i ON(" .
             join(' AND ', @{$joins->[$i]{'conditions'}}) . ")");

        $i++;
      }

      # Primary table first, then explicit joins, then implicit inner joins
      $tables_sql = join("\n", $primary_table, @joined_tables) .
                    (@normal_tables ? ",\n" . join(",\n", @normal_tables) : '');
    }
    else
    {
      my $i = 0;
      $tables_sql = $multi_table ?
        join(",\n", map { $i++; "  $_ t$i" } @$tables) :
        "  $tables->[0]";    
    }

    my $prefix_limit = (defined $limit && $use_prefix_limit) ? $limit : '';
    $select ||= join(",\n", map { "  $_" } @select_columns);
    $qs = "SELECT $prefix_limit\n$select\nFROM\n$tables_sql\n";
  }

  if($where)
  {
    if($where_only)
    {
      $qs = ' ' . $where;
    }
    else
    {
      $qs .= "WHERE\n" . $where;
    }
  }

  $qs .= "\nGROUP BY " . $group_by if($group_by);
  $qs .= "\nORDER BY " . $sort_by  if($sort_by);
  $qs .= "\nLIMIT "    . $limit    if(defined $limit && !$use_prefix_limit);

  $Debug && warn "$qs\n";

  return wantarray ? ($qs, \@bind) : $qs;
}

sub _build_clause
{
  my($dbh, $field, $op, $vals, $not, $field_mod, $bind, $db, $col_meta,
     $force_inline) = @_;

  if(!defined $op && ref $vals eq 'HASH' && keys(%$vals) == 1)
  {
    my $op_arg = (keys(%$vals))[0];

    if($op_arg =~ s/_sql$//)
    {
      $force_inline = 1;
    }

    $op = $OP_MAP{$op_arg} or 
      Carp::croak "Unknown comparison operator: $op_arg";
  }
  else { $op ||= '=' }

  my $ref;

  unless($ref = ref($vals))
  {
    $field = $field_mod  if($field_mod);

    my $should_inline = 
      ($db && $col_meta && $col_meta->should_inline_value($db, $vals));

    if(defined($vals))
    {
      if($bind && !$should_inline && !$force_inline)
      {
        push(@$bind, $vals);

        if($op =~ /^A(?:NY|LL) IN$/)
        {
          return ($not ? "$not " : '') . "? IN $field ";
        }
        else
        {
          return ($not ? "$not(" : '') . "$field $op ?"  . ($not ? ')' : '');
        }
      }

      if($op =~ /^A(?:NY|LL) IN$/)
      {
        return ($not ? "$not(" : '') . $dbh->quote($vals) . " $op $field " .
               $dbh->quote($vals)  . ($not ? ')' : '');
      }
      else
      {
        return ($not ? "$not(" : '') . "$field $op " .
               (($should_inline || $force_inline) ? $vals : 
                                                   $dbh->quote($vals)) . 
               ($not ? ')' : '');
      }
    }
    return "$field IS " . ($not ? "$not " : '') . 'NULL';
  }

  if($ref eq 'ARRAY')
  {
    if(@$vals)
    {
      if($op eq '=')
      {
        if($bind)
        {
          my @new_vals;

          foreach my $val (@$vals)
          {
            my $should_inline = 
              ($db && $col_meta && $col_meta->should_inline_value($db, $val));

            if($should_inline || $force_inline)
            {
              push(@new_vals, $val);            
            }
            else
            {
              push(@$bind, $val);
              push(@new_vals, '?');
            }
          }

          return "$field " . ($not ? "$not " : '') . 'IN (' . join(', ', @new_vals) . ')';
        }

        return "$field " . ($not ? "$not " : '') . 'IN (' . join(', ', map 
               {
                 ($force_inline || ($db && $col_meta && $col_meta->should_inline_value($db, $_))) ? 
                 $_ : $dbh->quote($_)
               }
               @$vals) . ')';
      }
      elsif($op =~ /^A(NY|LL) IN$/)
      {
        my $sep = ($1 eq 'NY') ? 'OR ' : 'AND ';

        if($bind)
        {
          return  ($not ? "$not " : '') . '(' . 
          join($sep, map
          {
            push(@$bind, $_);
            "? IN $field "
          }
          (ref $vals ? @$vals : ($vals))) . ')';
        }

        return  ($not ? "$not " : '') . '(' . 
        join($sep, map
        {
          $dbh->quote($_) . " IN $field "
        }
        (ref $vals ? @$vals : ($vals))) . ')';
      }

      if($bind)
      {
        my @new_vals;

        foreach my $val (@$vals)
        {
          my $should_inline = 
            ($db && $col_meta && $col_meta->should_inline_value($db, $val));

          if($should_inline || $force_inline)
          {
            push(@new_vals, $val);
          }
          else
          {
            push(@$bind, $val);
            push(@new_vals, '?');
          }
        }

        return '(' . join(' OR ', map { ($not ? "$not(" : '') . "$field $op $_" .
                                        ($not ? ')' : '') } @new_vals) . ')';
      }

      return '(' . join(' OR ', map 
      {
        ($not ? "$not(" : '') . "$field $op " . 
        (($force_inline || ($db && $col_meta && $col_meta->should_inline_value($db, $_))) ? $_ : $dbh->quote($_)) .
        ($not ? ')' : '')
      }
      @$vals) . ')';
    }

    return;
  }
  elsif($ref eq 'HASH')
  {
    my($sub_op, $field_mod, @clauses);

    $field_mod = delete $vals->{'field'}  if(exists $vals->{'field'});

    foreach my $raw_op (keys(%$vals))
    {
      $sub_op = $OP_MAP{$raw_op} || Carp::croak "Unknown comparison operator: $raw_op";

      if(!ref($vals->{$raw_op}))
      {
        push(@clauses, _build_clause($dbh, $field, $sub_op, $vals->{$raw_op}, $not, $field_mod, $bind, $db, $col_meta, $force_inline));
      }
      elsif(ref($vals->{$raw_op}) eq 'ARRAY')
      {
        foreach my $val (@{$vals->{$raw_op}})
        {
          push(@clauses, _build_clause($dbh, $field, $sub_op, $val, $not, $field_mod, $bind, $db, $col_meta, $force_inline));
        }
      }
      else
      {
        Carp::croak "Don't know how to handle comparison values: $vals->{$raw_op}";
      }
    }

    my $sep = ($op eq 'ALL IN') ? ' AND ' : ' OR ';

    return @clauses == 1 ? $clauses[0] : ('(' . join($sep, @clauses) . ')');
  }

  Carp::croak "Don't know how to handle comparison values $vals";
}

sub _format_value
{
  my($db, $store, $param, $object, $col_meta, $get_method, $set_method, $value, $asis, $depth) = @_;

  $depth ||= 1;

  if(!ref $value || $asis)
  {
    unless($col_meta->type eq 'set' && ref $store eq 'HASH' && $param =~ /^(?:a(?:ny|all)_)?in_set$/)
    {
      if($col_meta->manager_uses_method)
      {
        $object->$set_method($value);
        $value = $object->$get_method();
      }
      else
      {
        $value = $col_meta->format_value($db, $col_meta->parse_value($db, $value));
      }
    }
  }
  elsif(ref $value eq 'ARRAY')
  {
    if($asis || $col_meta->type eq 'array' ||
       ($col_meta->type eq 'set' && $depth == 1))
    {
      $value = _format_value($db, $value, undef, $object, $col_meta, $get_method, $set_method, $value, 1, $depth + 1);
    }
    elsif($col_meta->type ne 'set')
    {
      my @vals;

      foreach my $subval (@$value)
      {
        _format_value($db, \@vals, undef, $object, $col_meta, $get_method, $set_method, $subval, 0, $depth + 1);
      }

      $value = \@vals;
    }
  }
  elsif(ref $value eq 'HASH')
  {    
    foreach my $key (keys %$value)
    {
      _format_value($db, $value, $key, $object, $col_meta, $get_method, $set_method, $value->{$key}, 0, $depth + 1);
    }
  }
  else
  {
    if($col_meta->manager_uses_method)
    {
      $object->$set_method($value);
      $value = $object->$get_method();
    }
    else
    {
      $value = $col_meta->format_value($db, $col_meta->parse_value($db, $value));
    }
  }

  if(ref $store eq 'HASH')
  {
    defined $param || die "Missing param argument for hashref storage";
    $store->{$param} = $value;
  }
  elsif(ref $store eq 'ARRAY')
  {
    push(@$store, $value);
  }
  else { die "Don't know how to store $value in $store" }

  return $value;
}

1;

__END__

=head1 NAME

Rose::DB::Object::QueryBuilder - Build SQL queries on behalf of Rose::DB::Object::Manager.

=head1 SYNOPSIS

    use Rose::DB::Object::QueryBuilder qw(build_select);

    # Build simple query
    $sql = build_select
    (
      dbh     => $dbh,
      select  => 'COUNT(*)',
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type title date) ] },
      query   =>
      [
        category => [ 'sports', 'science' ],
        type     => 'news',
        title    => { like => [ '%million%', 
                                '%resident%' ] },
      ],
      query_is_sql => 1);

    $sth = $dbh->prepare($sql);
    $dbh->execute;
    $count = $sth->fetchrow_array;

    ...

    # Return query with placeholders, plus bind values
    ($sql, $bind) = build_select
    (
      dbh     => $dbh,
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type title date) ] },
      query   =>
      [
        category => [ 'sports', 'science' ],
        type     => 'news',
        title    => { like => [ '%million%', 
                                '%resident%' ] },
      ],
      query_is_sql => 1,
      sort_by      => 'title DESC, category',
      limit        => 5);

    $sth = $dbh->prepare($sql);
    $dbh->execute(@$bind);

    while($row = $sth->fetchrow_hashref) { ... }

    ...

    # Coerce query values into the right format
    ($sql, $bind) = build_select
    (
      db      => $db,
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type title date) ] },
      classes => { articles => 'Article' },
      query   =>
      [
        type     => 'news',
        date     => { lt => 'now' },
        date     => { gt => DateTime->new(...) },
      ],
      sort_by      => 'title DESC, category',
      limit        => 5);

    $sth = $dbh->prepare($sql);
    $dbh->execute(@$bind);

=head1 DESCRIPTION

C<Rose::DB::Object::QueryBuilder> is used to build SQL queries, primarily in service of the L<Rose::DB::Object::Manager> class.  It (optionally) exports two functions: C<build_select()> and C<build_where_clause()>.

=head1 FUNCTIONS

=over 4

=item B<build_select PARAMS>

Returns an SQL "select" query string (in scalar context) or an SQL "select" query string with placeholders and a reference to an array of bind values (in list context) constructed based on PARAMS.  Valid PARAMS are described below.

=over 4

=item B<clauses CLAUSES>

A reference to an array of extra SQL clauses to add to the "WHERE" portion of the query string.  This is the obligatory "escape hatch" for clauses that are not supported by arguments to the C<query> parameter.

=item B<columns HASHREF>

A reference to a hash keyed by table name, each of which points to a reference to an array of the names of the columns in that table.  Example:

    $sql = build_select(columns => 
                        {
                          table1 => [ 'col1', 'col2', ... ],
                          table2 => [ 'col1', 'col2', ... ],
                          ...
                        });

This argument is required.

=item B<db DB>

A L<Rose::DB>-derived object.  This argument is required if C<query_is_sql> is false or omitted.

=item B<dbh DBH>

A C<DBI> database handle already connected to the correct database.  If this argument is omitted, an attempt will be made to extract a database handle from the C<db> argument.  If this fails, or if there is no C<db> argument, a fatal error will occur.

=item B<group_by CLAUSE>

A fully formed SQL "GROUP BY ..." clause, sans the words "GROUP BY", or a reference to an array of strings to be joined with a comma and appended to the "GROUP BY" clause.

=item B<limit NUMBER>

A number to use in the "LIMIT ..." (or "FIRST ...") clause.

=item B<logic LOGIC>

A string indicating the logic that will be used to join the statements in the WHERE clause.  Valid values for LOGIC are "AND" and "OR".  If omitted, it defaults to "AND".

=item B<pretty BOOL>

If true, the SQL returned will have slightly nicer formatting.

=item B<select COLUMNS>

The names of the columns to select from the table.  COLUMNS may be a string of comma-separated column names, or a reference to an array of column names.  If this parameter is omitted, it defaults to all of the columns in all of the tables participating in the query (according to the value of the C<columns> argument).

=item B<sort_by CLAUSE>

A fully formed SQL "ORDER BY ..." clause, sans the words "ORDER BY", or a reference to an array of strings to be joined with a comma and appended to the "ORDER BY" clause.

=item B<tables TABLES>

A reference to an array of table names.  This argument is required.  A fatal error will occur if it is omitted.

If more than one table is in the list, then each table is aliased to "tN", where N is an ascending number starting with 1.  The tables are numbered according to their order in TABLES.  Example:

    $sql = build_select(tables => [ 'foo', 'bar', 'baz' ], ...);

    print $sql;

    # SELECT ... FROM
    #   foo AS t1,
    #   bar AS t2,
    #   baz AS t3
    # ...

Furthermore, if there is no explicit value for the C<select> parameter, then each selected column is aliased with a "tN_" prefix in a multi-table query.  Example:

    SELECT
      t1.id    AS t1_id,
      t1.name  AS t1_name,
      t2.id    AS t2_id,
      t2.name  AS t2_name
    FROM
      foo AS t1,
      bar AS t2
    WHERE
      ...

=item B<query PARAMS>

The query parameters, passed as a reference to an array of name/value pairs.  PARAMS may include an arbitrary list of selection parameters used to modify the "WHERE" clause of the SQL select statement.

Valid selection parameters are described below, along with the SQL clause they add to the select statement.

Simple equality:

    'NAME'  => "foo"        # COLUMN = 'foo'
    '!NAME' => "foo"        # NOT(COLUMN = 'foo')

    'NAME'  => [ "a", "b" ] # COLUMN IN ('a', 'b')
    '!NAME' => [ "a", "b" ] # COLUMN NOT(IN ('a', 'b'))

    'NAME'  => undef        # COLUMN IS NULL
    '!NAME' => undef        # COLUMN IS NOT NULL

Comparisons:

    NAME => { OP => "foo" } # COLUMN OP 'foo'

    # (COLUMN OP 'foo' OR COLUMN OP 'goo')
    NAME => { OP => [ "foo", "goo" ] }

"OP" can be any of the following:

    OP                  SQL operator
    -------------       ------------
    regex, regexp       REGEXP
    like                LIKE
    rlike               RLIKE
    ne                  <>
    eq                  =
    lt                  <
    gt                  >
    le                  <=
    ge                  >=

Set operations:

    # A IN COLUMN
    'NAME' => { in_set => 'A' } 

    # NOT(A IN COLUMN)
    '!NAME' => { in_set => 'A' } 

    # (A IN COLUMN OR B IN COLUMN)
    'NAME' => { in_set => [ 'A', 'B'] } 
    'NAME' => { any_in_set => [ 'A', 'B'] } 

    # NOT(A IN COLUMN OR B IN COLUMN)
    '!NAME' => { in_set => [ 'A', 'B'] } 
    '!NAME' => { any_in_set => [ 'A', 'B'] } 

    # (A IN COLUMN AND B IN COLUMN)
    'NAME' => { all_in_set => [ 'A', 'B'] } 

    # NOT(A IN COLUMN AND B IN COLUMN)
    '!NAME' => { all_in_set => [ 'A', 'B'] } 

The string "NAME" can take many forms, each of which eventually resolves to a database column (COLUMN in the examples above).

Any of these operations described above can have "_sql" appended to indicate that the corresponding values are to be "inlined" (i.e., included in the SQL query as-is, with no quoting of any kind).  This is useful for comparing two columns.  For example, this query:

    query => [ legs => { gt_sql => 'eyes' } ]

would produce this SQL:

    SELECT ... FROM animals WHERE legs > eyes

where "legs" and "eyes" are both column names in the "animals" table.

=over 4

=item C<column>

A bare column name.  If the query includes more than one table, the column name may be ambiguous if it appears in two or more tables.  In that case, a fatal error will occur.  To solve this, use one of the less ambiguous forms below.

=item C<table.column>

A column name and a table name joined by a dot.  This is the "fully qualified" column name.

=item C<tN.column>

A column name and a table alias joined by a dot.  The table alias is in the form "tN", where "N" is a number starting from 1.  See the documentation for C<tables> parameter above to learn how table aliases are assigned to tables.

=item Any of the above prefixed with "!"

This indicates the negation of the specified condition.

=back

If C<query_is_sql> is false or omitted, then NAME can also take on these additional forms:

=over 4

=item C<method>

A L<Rose::DB::Object> method name for an object fronting one of the tables being queried.  There may also be ambiguity here if the same method name is defined on more than one of the the objects that front the tables.  In such a case, the method will be mapped to the first L<Rose::DB::Object>-derived object that contains a method by that name, considered in the order that the tables are provided in the C<tables> parameter.

=item C<!method>

This indicates the negation of the specified condition.

=back

All of these clauses are joined by C<logic> (default: "AND") in the final query.  Example:

    $sql = build_select
    (
      dbh     => $dbh,
      select  => 'id, title',
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type title) ] },
      query   =>
      [
        category => [ 'sports', 'science' ],
        type     => 'news',
        title    => { like => [ '%million%', 
                                '%resident%' ] },
      ],
      query_is_sql => 1);

The above returns an SQL statement something like this:

    SELECT id, title FROM articles WHERE
      category IN ('sports', 'science')
      AND
      type = 'news'
      AND
      (title LIKE '%million%' OR title LIKE '%resident%')
    LIMIT 5

Nested boolean logic is possible using the special keywords C<and> and C<or> (case insensitive).  Example:

    $sql = build_select
    (
      dbh     => $dbh,
      select  => 'id, title',
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type title) ] },
      query   =>
      [
        or =>
        [
          and => [ category => undef, type => 'aux' ],
          category => [ 'sports', 'science' ],
        ],
        type     => 'news',
        title    => { like => [ '%million%', 
                                '%resident%' ] },
      ],
      query_is_sql => 1);

which returns an SQL statement something like this:

    SELECT id, title FROM articles WHERE
      (
        (
          category IS NULL AND
          type = 'aux'
        ) 
        OR category IN ('sports', 'science')
      )
      AND
      type = 'news'
      AND
      (title LIKE '%million%' OR title LIKE '%resident%')

If you have a column named "and" or "or", you'll have to use the fully-qualified (table.column) or alias-qualified (tN.column) forms in order to address the column.

If C<query_is_sql> is false or omitted, all of the parameter values are passed through the C<parse_value()> and C<format_value()> methods of their corresponding L<Rose::DB::Object::Metadata::Column>-dervied column objects.

If a column object returns true from its C<manager_uses_method()> method, then its parameter value is passed through the corresponding L<Rose::DB::Object>-derived object method instead.

Example:

    $dt = DateTime->new(year => 2001, month => 1, day => 31);

    $sql = build_select
    (
      db      => $db,
      select  => 'id, category',
      tables  => [ 'articles' ],
      columns => { articles => [ qw(id category type date) ] },
      classes => { articles => 'Article' },
      query   =>
      [
        type  => 'news',
        date  => { lt => '12/25/2003 8pm' },
        date  => { gt => $dt },
      ],
      sort_by => 'id DESC, category',
      limit   => 5);

The above returns an SQL statement something like this:

    SELECT id, category FROM articles WHERE
      type = 'news'
      AND
      date < '2003-12-25 20:00:00'
      AND
      date > '2001-01-31 00:00:00'
    ORDER BY id DESC, category
    LIMIT 5

Finally, here's an example using more than one table:

    $dt = DateTime->new(year => 2001, month => 1, day => 31);

    $sql = build_select
    (
      db      => $db,
      tables  => [ 'articles', 'categories' ],
      columns =>
      {
        articles   => [ qw(id name category_id date) ],
        categories => [ qw(id name description) ],
      },
      classes =>
      {
        articles   => 'Article',
        categories => 'Category',
      },
      query   =>
      [
        '!t1.name' => { like => '%foo%' },
        t2.name    => 'news',
        date       => { lt => '12/25/2003 8pm' },
        date       => { gt => $dt },
      ],
      clauses =>
      [
        't1.category_id = t2.id',
      ],
      sort_by      => 'articles.name DESC, t2.name',
      limit        => 5);

The above returns an SQL statement something like this:

    SELECT
      t1.id          AS t1_id,
      t1.name        AS t1_name,
      t1.category_id AS t1_category_id,
      t1.date        AS t1_date,
      t2.id          AS t2_id,
      t2.name        AS t2_name,
      t2.description AS t2_description
    FROM
      articles   t1,
      categories t2
    WHERE
      t1.category_id = t2.id
      AND
      NOT(t1.name LIKE '%foo%')
      AND
      t2.name = 'news'
      AND
      t1.date < '2003-12-25 20:00:00'
      AND
      t1.date > '2001-01-31 00:00:00'
    ORDER BY articles.name DESC, t2.name
    LIMIT 5

=item B<query_is_sql BOOL>

If omitted, this boolean flag is false.  If true, then the values of the C<query> parameters are taken as literal strings that are suitable for direct use in SQL queries.  Example:

    $sql = build_select
    (
      query_is_sql => 1,
      query =>
      [
        date => { lt => '2003-12-25 20:00:00' },
      ],
      ...
    );

Here the date value "2003-12-25 20:00:00" must be in the format that the current database expects for columns of that data type.

But if C<query_is_sql> is false or omitted, then any query value that can be handled by the L<Rose::DB::Object>-derived object method that services the corresponding database column is valid.  Example:

    $dt = DateTime->new(year => 2001, month => 1, day => 31);

    $sql = build_select
    (
      query =>
      [
        date => { gt => $dt },
        date => { lt => '12/25/2003 8pm' },
      ],
      ...
    );

Here a C<DateTime> object and a loosely formatted date are passed as values.  Provided the L<Rose::DB::Object>-derived object method that services the "date" column can handle such values, they will be parsed and formatted as appropriate for the current database.

The advantage of this approach is that the query values do not have to be so rigorously specified, nor do they have to be in a database-specific format.

The disadvantage is that all of this parsing and formatting is done for every query value, and that adds additional overhead to each call.

Usually, this overhead is dwarfed by the time required for the database to service the query, and, perhaps more importantly, the reduced maintenance headache and busywork required to properly format all query values.

In the end, it's up to the developer to decide on a case-by-case basis whether or not C<query_is_sql> should be true or false.

=back

=item B<build_where_clause PARAMS>

This works the same as the C<build_select()> function, except that it only returns the "WHERE" clause of the SQL query, sans the word "WHERE" and prefixed with a single space.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
