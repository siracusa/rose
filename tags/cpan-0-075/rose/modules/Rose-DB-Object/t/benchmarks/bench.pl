#!/usr/bin/perl

use strict;

use FindBin qw($Bin);

require "$Bin/../test-lib.pl";

use lib "$Bin/../../lib";
use lib "$Bin/lib";

use Rose::DB;

use Rose::DB::Object::Util qw(:all);

use Benchmark qw(timethese cmpthese); # :hireswallclock

our(%Have_PM, %Use_PM, %Have_DB, @Use_DBs, %Inited_DB, $DB, $DBH, $Term, $Pager);

our @Cmp_To = (qw(DBI Class::DBI Class::DBI::Sweet DBIx::Class));

our %Cmp_Abbreviation =
(
  'DBI'               => 'DBI',
  'Class::DBI'        => 'CDBI',
  'Class::DBI::Sweet' => 'CDBS',
  'DBIx::Class'       => 'DBIC',
);

our %DB_Name =
(
  pg       => 'PostgreSQL',
  mysql    => 'MySQL',
  informix => 'Informix',
);

our %DB_Tag;
@DB_Tag{values %DB_Name} = keys %DB_Name;

our $Default_CPU_Time   = 5;
our $Default_Iterations = 1000;
our $Min_DBI_Iterations = 3000;

use Getopt::Long;

our %Opt;

Getopt::Long::config('auto_abbrev');

GetOptions(\%Opt, 'help',
                  'skip-intro',
                  'benchmarks-match|filter|bench-match=s',
                  'debug',
                  'cpu-time=i',
                  'compare-to|cmp-to=s',
                  'time',
                  'compare',
                  'time-and-compare',
                  'simple',
                  'complex',
                  'iterations=i',
                  'simple-and-complex',
                  'hi-res-time',
                  'database|db=s') or Usage();

Usage()  if($Opt{'help'});

our $Debug = $Opt{'debug'} || 0;
our $CPU_Time = $Opt{'cpu-time'} || $Default_CPU_Time;
$CPU_Time = -$CPU_Time  if($CPU_Time > 0);

unless($Opt{'time'} || $Opt{'time-and-compare'})
{
  $Opt{'compare'} = 1;
  delete @Opt{qw(time time-and-compare)};
}

unless($Opt{'simple'} || $Opt{'complex'})
{
  $Opt{'simple-and-complex'} = 1;
  delete @Opt{qw(simple complex)};
}

our $Bench_Match = $Opt{'benchmarks-match'} ? qr($Opt{'benchmarks-match'}|insert) : 0;

our $Iterations = $Opt{'iterations'} || $Default_Iterations;

Benchmark->import(':hireswallclock')  if($Opt{'hi-res-time'});

MAIN:
{
  Init();

  foreach my $db_type (@Use_DBs)
  {
    print<<"EOF";

##
## Benchmark against @{[ join(', ', @Cmp_To) ]} using $DB_Name{$db_type}
##

EOF
    Rose::DB->default_type($db_type);

    require MyTest::RDBO::Simple::Code;
    require MyTest::RDBO::Simple::CodeName;
    require MyTest::RDBO::Simple::Category;
    require MyTest::RDBO::Simple::Product;

    if($Opt{'simple'} || $Opt{'simple-and-complex'})
    {
      require MyTest::RDBO::Simple::Product::Manager;
      require MyTest::RDBO::Simple::Category::Manager;
    }

    if($Opt{'complex'} || $Opt{'simple-and-complex'})
    {
      require MyTest::RDBO::Complex::Code;
      require MyTest::RDBO::Complex::CodeName;
      require MyTest::RDBO::Complex::Category;
      require MyTest::RDBO::Complex::Product;
      require MyTest::RDBO::Complex::Product::Manager;
      require MyTest::RDBO::Complex::Category::Manager;
    }

    $DB  = Rose::DB->new;
    $DBH = Rose::DB->new->retain_dbh;

    if($Use_PM{'Class::DBI'})
    {
      require MyTest::CDBI::Simple::Code;
      require MyTest::CDBI::Simple::CodeName;
      require MyTest::CDBI::Simple::Category;
      require MyTest::CDBI::Simple::Product;

      if($Opt{'complex'} || $Opt{'simple-and-complex'})
      {
        require MyTest::CDBI::Complex::Code;
        require MyTest::CDBI::Complex::CodeName;
        require MyTest::CDBI::Complex::Category;
        require MyTest::CDBI::Complex::Product;
      }

      MyTest::CDBI::Base->refresh;
    }

    if($Use_PM{'Class::DBI::Sweet'})
    {
      require MyTest::CDBI::Sweet::Simple::Code;
      require MyTest::CDBI::Sweet::Simple::CodeName;
      require MyTest::CDBI::Sweet::Simple::Category;
      require MyTest::CDBI::Sweet::Simple::Product;


      if($Opt{'complex'} || $Opt{'simple-and-complex'})
      {
        require MyTest::CDBI::Sweet::Complex::Code;
        require MyTest::CDBI::Sweet::Complex::CodeName;
        require MyTest::CDBI::Sweet::Complex::Category;
        require MyTest::CDBI::Sweet::Complex::Product;
      }      

      MyTest::CDBI::Sweet::Base->refresh;
    }

    if($Use_PM{'DBIx::Class'})
    {  
      require MyTest::DBIC::Simple::Code;
      require MyTest::DBIC::Simple::CodeName;
      require MyTest::DBIC::Simple::Category;
      require MyTest::DBIC::Simple::Product;

      if($Opt{'complex'} || $Opt{'simple-and-complex'})
      {
        require MyTest::DBIC::Complex::Code;
        require MyTest::DBIC::Complex::CodeName;
        require MyTest::DBIC::Complex::Category;
        require MyTest::DBIC::Complex::Product;
      }

      MyTest::DBIC::Base->refresh;
    }

    Run_Tests();
    print "\n";
  }
}

sub Get_Pager
{
  return $Pager if($Pager);

  foreach my $exe ($ENV{'PAGER'}, '/usr/bin/less', '/bin/less')
  {
    if(-x $exe)
    {
      $Pager = $exe;
      last;
    }
  }

  return $Pager;
}

sub Usage
{
  my $pager = Get_Pager();

  local $SIG{'PIPE'} = 'IGNORE';

  if($pager)
  {
    my $fh;
    open($fh, "| $pager -E") && select($fh);
  }

  my $prog = $0;
  $prog =~ s{.*/}{};

  print<<"EOF";
Usage: $prog --help | [--skip-intro] [--cpu-time <num>]
       [--compare-to <modules>] [--database <db>]
       [--time | --compare | --time-and-compare]
       [--simple | --complex | --simple-and-complex]
       [--iterations <num>] [--hi-res-time]
       [--benchmarks-match <regex>]

--benchmarks-match <regex>

    Only run benchmarks whose names match <regex>.  Note: the "insert" 
    benchmarks will always be run.  (Otherwise, there'd be no data to
    benchmark against.)

--compare-to | --cmp <modules>

    Benchmark against <modules>, which is a comma-separated list of
    one or more for the following: 

        @{[join(', ', @Cmp_To)]}

    The special value "all" can be used to specify all available modules.

--database <db>

    Use <db> to run benchmarks, where <db> is a one of the following 
    database types: 

        @{[join(', ', sort keys %DB_Name)]}

--cpu-time <num>

    The minimum amount of CPU time in seconds to spend on benchmarks
    that do not require a predictible number of iterations.  Defaults
    to $Default_CPU_Time.

--hi-res-time

    Use high-resolution wall-clock time measurement, if available.

--iterations <num>

    The number of iterations to use for benchmarks that must be run a
    predictible number of times.  The default is $Default_Iterations.

--time
--compare
--time-and-compare

    Select only one of these flags to specify whether to time, compare,
    or both time and compare each benchmark.  (perldoc Benchmark and 
    see the timethese() and cmpthese() functions.)  "Compare" is the 
    default.

--simple
--complex
--simple-and-complex

    Select only one of these flags to specify whether to test with
    simple objects (no column inflate/deflate), complex objects,
    or both.  "Simple and complex" is the default.

--help        Show this help screen.
--skip-intro  Skip the introductory message.

EOF

  exit(1);
}

sub NVL { defined $ENV{$_[0]} ? $ENV{$_[0]} : $_[1] }

sub Init
{
  Init_Term();

  Init_PM();

  unless(%Have_PM)
  {
    print "Could not load any comparison modules: ",
          join(', ', sort keys %Have_PM), "\nExiting...\n";
    exit(1);
  }

  unless($Opt{'skip-intro'})
  {
    my $pager = Get_Pager();

    local $SIG{'PIPE'} = 'IGNORE';

    if($pager)
    {
      my $fh;
      open($fh, "| $pager -E") && select($fh);
    }

    print<<"EOF";

##
## WARNING: These benchmarks need to connect to a database in order to run.
## The benchmarks need full privileges on this database: the ability to
## create and drop tables, insert, update, and delete rows, create schemas,
## sequences, functions, triggers, the works.
## 
## By default, the benchmarks will try to connect to the database named
## "test" running on "localhost" using the default superuser username for
## each database type and an empty password.
## 
## If you have setup your database in a secure manner, these connection
## attempts will fail, and the benchmarks will be skipped.  If you want to
## override these values, set the following environment variables before
## running tests. (The current values are shown in parentheses.)
## 
## Postgres:
## 
##     RDBO_PG_DSN      (@{[ NVL('RDBO_PG_DSN', 'dbi:Pg:dbname=test;host=localhost') ]})
##     RDBO_PG_USER     (@{[ NVL('RDBO_PG_USER', 'postgres') ]})
##     RDBO_PG_PASS     (@{[ NVL('RDBO_PG_PASS', '<none>') ]})
## 
## MySQL:
## 
##     RDBO_MYSQL_DSN   (@{[ NVL('RDBO_MYSQL_DSN', 'dbi:mysql:database=test;host=localhost') ]})
##     RDBO_MYSQL_USER  (@{[ NVL('RDBO_MYSQL_USER', 'root') ]})
##     RDBO_MYSQL_PASS  (@{[ NVL('RDBO_MYSQL_PASS', '<none>') ]})
##
## Informix:
## 
##     RDBO_INFORMIX_DSN   (@{[ NVL('RDBO_INFORMIX_DSN', 'dbi:Informix:test@test') ]})
##     RDBO_INFORMIX_USER  (@{[ NVL('RDBO_INFORMIX_USER', '<none>') ]})
##     RDBO_INFORMIX_PASS  (@{[ NVL('RDBO_INFORMIX_PASS', '<none>') ]})
## 
## Press return to continue (or wait 60 seconds)
EOF

    select(STDOUT);

    my %old;

    $old{'ALRM'} = $SIG{'ALRM'} || 'DEFAULT';

    eval
    {
      # Localize so I only have to restore in my catch block
      local $SIG{'ALRM'} = sub { die 'alarm' };
      alarm(60);
      my $res = <STDIN>;
      alarm(0);
    };

    if($@ =~ /alarm/)
    {
      $SIG{'ALRM'} = $old{'ALRM'};
    }
  }

  Check_DB();

  unless(%Have_DB)
  {
    print "Could not connect to any databases.  Exiting...\n";
    exit(1);
  }

  my $question =<<"EOF";
The following comparison modules were found:

@{[join("\n", map { "    $_" } sort keys %Have_PM)]}

Which ones would you like to compare with?
EOF

  WHICH_PM: 
  {
    my $response = 
      $Opt{'compare-to'} ? $Opt{'compare-to'} :
      (keys %Have_PM == 1) ? (keys %Have_PM)[0] :
      Ask(question   => $question,
          prompt     => 'Compare with',
          default    => join(', ', sort grep { $_ ne 'DBI' } keys %Have_PM),
          no_newline => 1);

    $response =~ s/,/ /g;
    @Cmp_To = split(/\s+/, $response);

    foreach my $pm (@Cmp_To)
    {
      unless($Cmp_Abbreviation{$pm})
      {
        print "\n*** ERROR: Unknown module: '$pm'\n\n";
        sleep(1);
        exit(1)  if($Opt{'compare-to'});
        redo WHICH_PM;
      }

      unless($Have_PM{$pm})
      {
        print "\n*** ERROR: Do not have module '$pm'\n\n";
        sleep(1);
        exit(1)  if($Opt{'compare-to'});
        redo WHICH_PM;
      }
    }
  }

  %Use_PM = map { $_ => 1 } @Cmp_To;

  $question =<<"EOF";
The following databases are configured:

@{[join("\n", map { "    $DB_Name{$_}" } sort keys %Have_DB)]}

Which one would you like to use?
EOF

  WHICH_DB:
  {
    my $response = 
      $Opt{'database'} ? $Opt{'database'} :
      Ask(question   => $question,
          prompt     => 'Use database',
          default    => (map { $DB_Name{$_} } sort keys %Have_DB)[0]);

    $response =~ s/,/ /g;
    @Use_DBs = split(/\s+/, $response);

    foreach my $db (@Use_DBs)
    {
      unless($DB_Name{$db} || $DB_Tag{$db})
      {
        print "\n*** ERROR: Unknown or unavailable database: '$db'\n\n";
        sleep(1);
        exit(1)  if($Opt{'database'});
        redo WHICH_DB;
      }

      $db = $DB_Tag{$db}  if($DB_Tag{$db});
    }
  }

  if(@Use_DBs > 1)
  {
    warn<<"EOF";

*** WARNING: benchmarks may fail when trying to use multiple databases.

EOF
  }

  Init_DB();

  # Not supporting DBI test on Informix right now due to the stupid way it
  # does limits and offsets...or rather, *doesn't* handle offsets in
  # informix versions prior to 10.
  if($Inited_DB{'informix'} && $Use_PM{'DBI'})
  {
    die<<"EOF";
*** ERROR: DBI tests not supported on Informix ***

Cannot benchmark against DBI using the Informix database due to Informix's
limited support for "limit with offset" in SELECT statements.  Please choose
a different database.

EOF
  }

  # Warn about speedy DBI causing too few iterations
  if(!$Opt{'iterations'} && $Use_PM{'DBI'} && $Iterations < $Min_DBI_Iterations)
  {
    warn<<"EOF";

*** WARNING ***

When benchmarking against DBI, you may need to increase the number of
iterations to at least $Min_DBI_Iterations in oder to avoid a warning about "too few
iterations" from the Benchmark.pm module.  (That number may be different,
depending on how fast your system is.)  Consider running the benchmark
again with "--iterations $Min_DBI_Iterations"

Press return to continue (or wait 60 seconds)
EOF

    my %old;

    $old{'ALRM'} = $SIG{'ALRM'} || 'DEFAULT';

    eval
    {
      # Localize so I only have to restore in my catch block
      local $SIG{'ALRM'} = sub { die 'alarm' };
      alarm(60);
      my $res = <STDIN>;
      alarm(0);
    };

    if($@ =~ /alarm/)
    {
      $SIG{'ALRM'} = $old{'ALRM'};
    }
  }
}

sub Init_PM
{
  foreach my $class (@Cmp_To)
  {
    eval "use $class";
    $Have_PM{$class} = 1  unless($@);
  }

  $Opt{'compare-to'} = join(',', sort keys %Have_PM)  if($Opt{'compare-to'} eq 'all');
}

sub Init_Term
{
  eval { require Term::ReadLine };

  return  if($@);

  $Term = Term::ReadLine->new('bench');

  if($Term->ReadLine =~ /::Stub$/) # the stub doesn't do what we need
  {
    $Term = undef;
    return;
  }
  else
  {
    # Get rid of that underlining crap
    $Term->ornaments(0);

    ($Term->OUT) ? select($Term->OUT) : select(STDOUT);
  }
}

sub Ask
{
  my(%args) = @_;

  my $response;

  ASK:
  {
    for($args{'question'})
    {
      s/\A\n*/\n/  unless($args{'no_newline'});
      s/\s*\Z/\n\n/;
    }

    print $args{'question'};

    $response = Prompt(prompt  => $args{'prompt'},
                       default => $args{'default'});

    redo ASK  unless(defined $response);
  }

  return $response;
}

sub Prompt
{
  my(%args) = @_;

  %args = (prompt => $_[1])  if(@_ == 2);

  my($term, $response);

  if($Term)
  {
    $args{'prompt'} .= ': '  unless($args{'prompt'} =~ /\s$/);
    $response = $Term->readline($args{'prompt'}, $args{'default'})
  }
  else
  {
    print "$args{'prompt'} ($args{'default'}): ";
    chomp($response = <STDIN>);
  }

  unless($response =~ /\S/)
  {
    $response = $args{'default'}  if(!$Term && length $args{'default'});
    $Term->addhistory($response)  if($Term);
  }

  return $response;
}

use constant MAX_CODE_NAMES_RANGE => 10;
use constant MIN_CODE_NAMES       => 1;

sub Insert_Code_Names
{
  if($Bench_Match && 
     'Simple: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match &&
     'Complex: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match)
  {
    return;
  }

  local $|= 1;
  print "\n# Inserting 1-to-n records";

  my %cmp = map { $_ => 1 } @Cmp_To;

  my $sql = 'INSERT INTO rose_db_object_test_code_names (product_id, name) VALUES (?, ?)';

  my $dbi_factor = $Opt{'simple-and-complex'} ? 2 : 1;

  foreach my $db_name (@Use_DBs)
  {
    my $db = Rose::DB->new($db_name);

    $db->autocommit(0);
    $db->begin_work;

    my $dbh = $db->dbh;

    my $sth = $dbh->prepare($sql);

    # RDBO
    foreach my $i (1 .. $Iterations)
    {
      foreach my $n (1 .. (int rand(MAX_CODE_NAMES_RANGE) + MIN_CODE_NAMES))
      {
        $sth->execute($i + 100_000, "CN 1x$n $i");
        $sth->execute($i + 1_100_000, "CN 1.1x$n $i");
      }
    }

    print '.';

    # CDBI
    if($cmp{'Class::DBI'})
    {
      foreach my $i (1 .. $Iterations)
      {
        foreach my $n (1 .. (int rand(MAX_CODE_NAMES_RANGE) + MIN_CODE_NAMES))
        {
          $sth->execute($i + 200_000, "CN 2x$n $i");
          $sth->execute($i + 2_200_000, "CN 2.2x$n $i");
        }
      }    
    }

    print '.';

    # CDBS
    if($cmp{'Class::DBI::Sweet'})
    {
      foreach my $i (1 .. $Iterations)
      {
        foreach my $n (1 .. (int rand(MAX_CODE_NAMES_RANGE) + MIN_CODE_NAMES))
        {
          $sth->execute($i + 400_000, "CN 4x$n $i");
          $sth->execute($i + 4_400_000, "CN 4.4x$n $i");
        }
      }
    }

    print '.';

    # DBIC
    if($cmp{'DBIx::Class'})
    {
      foreach my $i (1 .. $Iterations)
      {
        foreach my $n (1 .. (int rand(MAX_CODE_NAMES_RANGE) + MIN_CODE_NAMES))
        {
          $sth->execute($i + 300_000, "CN 3x$n $i");
          $sth->execute($i + 3_300_000, "CN 3.3x$n $i");
        }
      }
    }

    print '.';

    # DBI
    if($cmp{'DBI'})
    {
      foreach my $i (1 .. ($Iterations * $dbi_factor))
      {
        foreach my $n (1 .. (int rand(MAX_CODE_NAMES_RANGE) + MIN_CODE_NAMES))
        {
          $sth->execute($i + 500_000, "CN 5x$n $i");
          # No "complex" DBI tests
          #$sth->execute($i + 5_500_000, "CN 5.5x$n $i");
        }
      }
    }

    $db->commit;
    print ".\n";
  }
}

sub Make_Indexes
{
  if($Bench_Match && 
     'Simple: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match &&
     'Complex: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match &&
     'Simple: search with 1-to-1 sub-objects' !~ $Bench_Match &&
     'Complex: search with 1-to-1 sub-objects' !~ $Bench_Match)
  {
    return;
  }

  print "\n# Making indexes...\n";

  my %cmp = map { $_ => 1 } @Cmp_To;

  foreach my $db_name (@Use_DBs)
  {
    my $db = Rose::DB->new($db_name);

    my $dbh = $db->dbh;

    $dbh->do(<<"EOF");
CREATE INDEX rose_db_object_test_products_name_idx ON rose_db_object_test_products (name)
EOF

    $dbh->do(<<"EOF");
CREATE INDEX rose_db_object_test_code_names_pid_idx ON rose_db_object_test_code_names (product_id)
EOF
  }
}

sub Drop_Indexes
{
  if($Bench_Match && 
     'Simple: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match &&
     'Complex: search with 1-to-1 and 1-to-n sub-objects' !~ $Bench_Match &&
     'Simple: search with 1-to-1 sub-objects' !~ $Bench_Match &&
     'Complex: search with 1-to-1 sub-objects' !~ $Bench_Match)
  {
    return;
  }

  print "\n# Dropping indexes...\n";

  my %cmp = map { $_ => 1 } @Cmp_To;

  foreach my $db_name (@Use_DBs)
  {
    my $db = Rose::DB->new($db_name);

    my $dbh = $db->dbh;

    my $on = ($db_name eq 'mysql') ? 'ON rose_db_object_test_products' : '';

    $dbh->do(<<"EOF");
DROP INDEX rose_db_object_test_products_name_idx $on
EOF

    $on = ($db_name eq 'mysql') ? 'ON rose_db_object_test_code_names' : '';

    $dbh->do(<<"EOF");
DROP INDEX rose_db_object_test_code_names_pid_idx $on
EOF

    $dbh->do(<<"EOF");
DELETE FROM rose_db_object_test_code_names
EOF
  }
}

##
## Benchmark subroutines
##

BEGIN
{
  ##
  ## Simple
  ##

  #
  # Insert
  #

  INSERT_SIMPLE_CATEGORY_DBI:
  {
    my $i = 1;

    sub insert_simple_category_dbi
    {
      my $sth = $DBH->prepare('INSERT INTO rose_db_object_test_categories (id, name) VALUES (?, ?)');
      $sth->execute($i + 500_000,  "xCat $i");
      $i++;
    }
  }

  INSERT_SIMPLE_CATEGORY_RDBO:
  {
    my $i = 1;

    sub insert_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category->new(
          db   => $DB, 
          id   => $i + 100_000, 
          name => "xCat $i");
      $c->save;
      $i++;
    }
  }

  INSERT_SIMPLE_CATEGORY_CDBI:
  {
    my $i = 1;

    sub insert_simple_category_cdbi
    {
      MyTest::CDBI::Simple::Category->create({ id => $i + 200_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_SIMPLE_CATEGORY_CDBS:
  {
    my $i = 1;

    sub insert_simple_category_cdbs
    {
      MyTest::CDBI::Sweet::Simple::Category->create({ id => $i + 400_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_SIMPLE_CATEGORY_DBIC:
  {
    my $i = 1;

    sub insert_simple_category_dbic
    {
      MyTest::DBIC::Simple::Category->create({ id => $i + 300_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_SIMPLE_PRODUCT_DBI:
  {
    my $i = 1;

    sub insert_simple_product_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
INSERT INTO rose_db_object_test_products
(
  id,
  name,
  category_id,
  status,
  published,
  last_modified,
  date_created
) 
VALUES (?, ?, ?, ?, ?, ?, ?)
EOF

      $sth->execute($i + 500_000, 
                    "Product $i", 
                    2,
                    'temp',
                    '2005-01-02 12:34:56',
                    '2005-02-02 12:34:56',
                    '2005-03-02 12:34:56');
      $i++;
    }
  }


  INSERT_SIMPLE_PRODUCT_RDBO:
  {
    my $i = 1;

    sub insert_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product->new(
          db            => $DB, 
          id            => $i + 100_000, 
          name          => "Product $i",
          category_id   => 2,
          status        => 'temp',
          published     => '2005-01-02 12:34:56',
          last_modified => '2005-02-02 12:34:56',
          date_created  => '2005-03-02 12:34:56');
      $p->save;
      $i++;
    }
  }

  INSERT_SIMPLE_PRODUCT_CDBI:
  {
    my $i = 1;

    sub insert_simple_product_cdbi
    {
      MyTest::CDBI::Simple::Product->create({
        id            => $i + 200_000, 
        name          => "Product $i",
        category_id   => 2,
        status        => 'temp',
        published     => '2005-01-02 12:34:56',
        last_modified => '2005-02-02 12:34:56',
        date_created  => '2005-03-02 12:34:56' });
      $i++;
    }
  }

  INSERT_SIMPLE_PRODUCT_CDBS:
  {
    my $i = 1;

    sub insert_simple_product_cdbs
    {
      MyTest::CDBI::Sweet::Simple::Product->create({
        id            => $i + 400_000, 
        name          => "Product $i",
        category_id   => 2,
        status        => 'temp',
        published     => '2005-01-02 12:34:56',
        last_modified => '2005-02-02 12:34:56',
        date_created  => '2005-03-02 12:34:56' });
      $i++;
    }
  }

  INSERT_SIMPLE_PRODUCT_DBIC:
  {
    my $i = 1;

    sub insert_simple_product_dbic
    {
      MyTest::DBIC::Simple::Product->create({
        id            => $i + 300_000, 
        name          => "Product $i",
        category_id   => 2,
        status        => 'temp',
        published     => '2005-01-02 12:34:56',
        last_modified => '2005-02-02 12:34:56',
        date_created  => '2005-03-02 12:34:56' });
      $i++;
    }
  }

  #
  # Accessor
  #

  use constant ACCESSOR_ITERATIONS => 10_000;

  ACCCESSOR_SIMPLE_CATEGORY_DBI:
  {
    sub accessor_simple_category_dbi
    {
      my $sth = $DBH->prepare('SELECT id, name FROM rose_db_object_test_categories WHERE id = ?');
      $sth->execute(1 + 500_000);
      my $c = $sth->fetchrow_hashref;

      # Use hash key access to simulate accessor methods
      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          my $v = $c->{$_};
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_CATEGORY_RDBO:
  {
    sub accessor_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category->new(
          db  => $DB,
          id  => 1 + 100_000);

      $c->load;

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_CATEGORY_CDBI:
  {
    sub accessor_simple_category_cdbi
    {
      my $c = MyTest::CDBI::Simple::Category->retrieve(1 + 200_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_CATEGORY_CDBS:
  {
    sub accessor_simple_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Category->retrieve(1 + 400_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_CATEGORY_DBIC:
  {
    sub accessor_simple_category_dbic
    {
      my $c = MyTest::DBIC::Simple::Category->find(1 + 300_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_PRODUCT_DBI:
  {
    sub accessor_simple_product_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT id, name, status, fk1, fk2, fk3, published, last_modified, date_created
FROM rose_db_object_test_products WHERE id = ?
EOF
      $sth->execute(1 + 500_000);
      my $p = $sth->fetchrow_hashref;

      # Use hash key access to simulate accessor methods
      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          my $v = $p->{$_};
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_PRODUCT_RDBO:
  {
    sub accessor_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product->new(
          db => $DB, 
          id => 1 + 100_000);

      $p->load;

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_PRODUCT_CDBI:
  {
    sub accessor_simple_product_cdbi
    {
      my $p = MyTest::CDBI::Simple::Product->retrieve(1 + 200_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_PRODUCT_CDBS:
  {
    sub accessor_simple_product_cdbs
    {
      my $p = MyTest::CDBI::Sweet::Simple::Product->retrieve(1 + 400_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_SIMPLE_PRODUCT_DBIC:
  {
    sub accessor_simple_product_dbic
    {
      my $p = MyTest::DBIC::Simple::Product->find(1 + 300_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  #
  # Load
  #

  LOAD_SIMPLE_CATEGORY_DBI:
  {
    my $i = 1;

    sub load_simple_category_dbi
    {
      my $sth = $DBH->prepare('SELECT id, name FROM rose_db_object_test_categories WHERE id = ?');
      $sth->execute($i + 500_000);
      my $c = $sth->fetchrow_hashref;
      $i++;
    }
  }

  LOAD_SIMPLE_CATEGORY_RDBO:
  {
    my $i = 1;

    sub load_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category->new(
          db => $DB, 
          id => $i + 100_000);
      $c->load;
      $i++;
    }
  }

  LOAD_SIMPLE_CATEGORY_CDBI:
  {
    my $i = 1;

    sub load_simple_category_cdbi
    {
      my $c = MyTest::CDBI::Simple::Category->retrieve($i + 200_000);
      $i++;
    }
  }

  LOAD_SIMPLE_CATEGORY_CDBS:
  {
    my $i = 1;

    sub load_simple_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Category->retrieve($i + 400_000);
      $i++;
    }
  }

  LOAD_SIMPLE_CATEGORY_DBIC:
  {
    my $i = 1;

    sub load_simple_category_dbic
    {
      my $c = MyTest::DBIC::Simple::Category->find($i + 300_000);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_DBI:
  {
    my $i = 1;

    sub load_simple_product_dbi
    {
      my $sth = $DBH->prepare('SELECT id, name, category_id, status, fk1, fk2, fk3, published, last_modified, date_created FROM rose_db_object_test_products WHERE id = ?');
      $sth->execute($i + 500_000);
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published last_modified date_created)});
      $sth->fetch;
      $i++;
    }
  }


  LOAD_SIMPLE_PRODUCT_RDBO:
  {
    my $i = 1;

    sub load_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product->new(
          db => $DB, 
          id => $i + 100_000);
      $p->load;
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_CDBI:
  {
    my $i = 1;

    sub load_simple_product_cdbi
    {
      my $c = MyTest::CDBI::Simple::Product->retrieve($i + 200_000);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_CDBS:
  {
    my $i = 1;

    sub load_simple_product_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Product->retrieve($i + 400_000);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_DBIC:
  {
    my $i = 1;

    sub load_simple_product_dbic
    {
      my $c = MyTest::DBIC::Simple::Product->find($i + 300_000);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_AND_CATEGORY_DBI:
  {
    my $i = 1;

    sub load_simple_product_and_category_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  p.id,
  p.name,
  p.category_id,
  p.status,
  p.fk1,
  p.fk2,
  p.fk3,
  p.published,
  p.last_modified,
  p.date_created,
  c.id,
  c.name
FROM
  rose_db_object_test_products p,
  rose_db_object_test_categories c
WHERE
  c.id = p.category_id AND
  p.id = ?
EOF

      $sth->execute($i + 500_000);
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published
                                  last_modified date_created cat_id cat_name)});

      $sth->fetch;

      my $n = $row{'cat_name'};
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $i = 1;

    sub load_simple_product_and_category_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product->new(
          db => $DB, 
          id => $i + 100_000);
      $p->load;

      my $cat = $p->category;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $i = 1;

    sub load_simple_product_and_category_cdbi
    {
      my $c = MyTest::CDBI::Simple::Product->retrieve($i + 200_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $i = 1;

    sub load_simple_product_and_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Product->retrieve($i + 400_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_SIMPLE_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $i = 1;

    sub load_simple_product_and_category_dbic
    {
      my $c = MyTest::DBIC::Simple::Product->find($i + 300_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  #
  # Update
  #

  UPDATE_SIMPLE_CATEGORY_DBI:
  {
    my $i = 1;

    sub update_simple_category_dbi
    {
      my $sth = $DBH->prepare('SELECT id, name FROM rose_db_object_test_categories WHERE id = ?');
      $sth->execute($i + 500_000);
      my($name, $category);
      $sth->bind_columns(\$name, \$category);
      $sth->fetch;
      $name .= ' updated';

      my $usth = $DBH->prepare('UPDATE rose_db_object_test_categories SET name = ? WHERE id = ?');
      $usth->execute($name, $i + 500_000);

      $i++;
    }
  }

  UPDATE_SIMPLE_CATEGORY_RDBO:
  {
    my $i = 1;

    sub update_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category->new(
          db => $DB, 
          id => $i + 100_000);
      $c->load;
      $c->name($c->name . ' updated');
      $c->save;
      $i++;
    }
  }

  UPDATE_SIMPLE_CATEGORY_CDBI:
  {
    my $i = 1;

    sub update_simple_category_cdbi
    {
      my $c = MyTest::CDBI::Simple::Category->retrieve($i + 200_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_SIMPLE_CATEGORY_CDBS:
  {
    my $i = 1;

    sub update_simple_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Category->retrieve($i + 400_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_SIMPLE_CATEGORY_DBIC:
  {
    my $i = 1;

    sub update_simple_category_dbic
    {
      my $c = MyTest::DBIC::Simple::Category->find($i + 300_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_SIMPLE_PRODUCT_DBI:
  {
    my $i = 1;

    sub update_simple_product_dbi
    {
      my $sth = $DBH->prepare('SELECT id, name, category_id, status, fk1, fk2, fk3, published, last_modified, date_created FROM rose_db_object_test_products WHERE id = ?');
      $sth->execute($i + 500_000);
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published last_modified date_created)});
      $sth->fetch;

      $row{'name'} .= ' updated';

      my $usth = $DBH->prepare('UPDATE rose_db_object_test_products SET name = ? WHERE id = ?');
      $usth->execute($row{'name'}, $i + 500_000);

      $i++;
    }
  }

  UPDATE_SIMPLE_PRODUCT_RDBO:
  {
    my $i = 1;

    sub update_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product->new(
          db => $DB, 
          id => $i + 100_000);
      $p->load;
      $p->name($p->name . ' updated');
      $p->save;
      $i++;
    }
  }

  UPDATE_SIMPLE_PRODUCT_CDBI:
  {
    my $i = 1;

    sub update_simple_product_cdbi
    {
      my $p = MyTest::CDBI::Simple::Product->retrieve($i + 200_000);
      $p->name($p->name . ' updated');
      $p->update;
      $i++;
    }
  }

  UPDATE_SIMPLE_PRODUCT_CDBS:
  {
    my $i = 1;

    sub update_simple_product_cdbs
    {
      my $p = MyTest::CDBI::Sweet::Simple::Product->retrieve($i + 400_000);
      $p->name($p->name . ' updated');
      $p->update;
      $i++;
    }
  }

  UPDATE_SIMPLE_PRODUCT_DBIC:
  {
    my $i = 1;

    sub update_simple_product_dbic
    {
      my $p = MyTest::DBIC::Simple::Product->find($i + 300_000);
      $p->name($p->name . ' updated');
      $p->update;
      $i++;
    }
  }

  #
  # Search
  #

  SEARCH_SIMPLE_CATEGORY_DBI:
  {
    my $printed = 0;

    sub search_simple_category_dbi
    {
      my $sth = $DBH->prepare("SELECT id, name FROM rose_db_object_test_categories WHERE name LIKE 'xCat %2%'");
      $sth->execute;
      my $c = $sth->fetchall_arrayref;
      die unless(@$c);

      if($Debug && !$printed)
      {
        print "search_simple_category_dbi GOT ", scalar(@$c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub search_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category::Manager->get_categories(
          db => $DB,
          query =>
          [
            name => { like => 'xCat %2%' },
          ]);
      die unless(@$c);

      if($Debug && !$printed)
      {
        print "search_simple_category_rdbo GOT ", scalar(@$c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub search_simple_category_cdbi
    {
      my @c = MyTest::CDBI::Simple::Category->search_like(name => 'xCat %2%');
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_simple_category_cdbi GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub search_simple_category_cdbs
    {
      my @c = MyTest::CDBI::Sweet::Simple::Category->search_like(name => 'xCat %2%');
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_simple_category_cdbs GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub search_simple_category_dbic
    {
      my @c = MyTest::DBIC::Simple::Category->search_like({ name => 'xCat %2%' });
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_simple_category_dbic GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_DBI:
  {
    my $printed = 0;

    sub search_simple_product_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  id,
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3,
  published,
  last_modified,
  date_created
FROM
  rose_db_object_test_products
WHERE
  name LIKE 'Product %2%'
EOF
      $sth->execute;
      my $p = $sth->fetchall_arrayref;
      die unless(@$p);

      if($Debug && !$printed)
      {
        print "search_simple_product_dbi GOT ", scalar(@$p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub search_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            name => { like => 'Product %2%' },
          ]);
      die unless(@$p);

      if($Debug && !$printed)
      {
        print "search_simple_product_rdbo GOT ", scalar(@$p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub search_simple_product_cdbi
    {
      my @p = MyTest::CDBI::Simple::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub search_simple_product_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Simple::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub search_simple_product_dbic
    {
      my @p = MyTest::DBIC::Simple::Product->search_like({ name => 'Product %2%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_DBI:
  {
    my $printed = 0;

    sub search_simple_product_and_category_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  p.id,
  p.name,
  p.category_id,
  p.status,
  p.fk1,
  p.fk2,
  p.fk3,
  p.published,
  p.last_modified,
  p.date_created,
  c.id,
  c.name
FROM
  rose_db_object_test_products p,
  rose_db_object_test_categories c
WHERE
  c.id = p.category_id AND
  p.name LIKE 'Product %2%'
EOF

      $sth->execute;
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published
                                  last_modified date_created cat_id cat_name)});

      my @ps;

      while($sth->fetch)
      {
        push(@ps, { %row });
      }

      die unless(@ps);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_dbi GOT ", scalar(@ps), "\n";
        $printed++;
      }

      foreach my $p (@ps)
      {
        my $n = $p->{'cat_name'};
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub search_simple_product_and_category_rdbo
    {
      my $ps =
        MyTest::RDBO::Simple::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product %2%' },
          ],
          require_objects => [ 'category' ]);
      die unless(@$ps);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_rdbo GOT ", scalar(@$ps), "\n";
        $printed++;
      }

      foreach my $p (@$ps)
      {
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub search_simple_product_and_category_cdbi
    {
      my @p = MyTest::CDBI::Simple::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub search_simple_product_and_category_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Simple::Product->search(
        { name => { -like => [ 'Product %2%' ] } },
        { prefetch => [ 'category_id' ] });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub search_simple_product_and_category_dbic
    {
      my @p = MyTest::DBIC::Simple::Product->search_like({ name => 'Product %2%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  #
  # Search with 1-to-1 and 1-to-n sub-objects
  #

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_DBI:
  {
    my $printed = 0;

    sub search_simple_product_and_category_and_code_name_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  p.id,
  p.name,
  p.category_id,
  p.status,
  p.fk1,
  p.fk2,
  p.fk3,
  p.published,
  p.last_modified,
  p.date_created,
  c.id,
  c.name,
  n.id, 
  n.product_id,
  n.name
FROM
  rose_db_object_test_products p
  LEFT OUTER JOIN rose_db_object_test_code_names n ON(n.product_id = p.id),
  rose_db_object_test_categories c
WHERE
  c.id = p.category_id AND
  n.product_id = p.id AND
  p.name LIKE 'Product 200%'
EOF

      $sth->execute;
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published
                                  last_modified date_created cat_id cat_name
                                  cn_id cn_product_id cn_name)});

      my @ps;

      while($sth->fetch)
      {
        push(@ps, { %row });
      }

      die unless(@ps);

      if($Debug && !$printed)
      {
        my(%seen, $num);

        foreach my $p (@ps)
        {
          $num++  unless($seen{$p->{'id'}}++);
        }

        print "search_simple_product_and_category_and_code_name_dbi GOT $num\n";
        #$printed++;
      }

      foreach my $p (@ps)
      {
        my $n = $p->{'cat_name'};
        die  unless($n =~ /\S/);
        my $cn = $p->{'cn_name'};
        die  unless($cn =~ /^CN /);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_RDBO:
  {
    my $printed = 0;

    sub search_simple_product_and_category_and_code_name_rdbo
    {
      #local $Rose::DB::Object::Manager::Debug = 1;
      my $ps =
        MyTest::RDBO::Simple::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product 200%' },
          ],
          with_objects    => [ 'code_names' ],
          require_objects => [ 'category' ]);
      die unless(@$ps);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_and_code_name_rdbo GOT ", scalar(@$ps), "\n";
        #$printed++;
      }

      foreach my $p (@$ps)
      {
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = $p->code_names->[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_CDBI:
  {
    my $printed = 0;

    sub search_simple_product_and_category_and_code_name_cdbi
    {
      my @p = MyTest::CDBI::Simple::Product->search_like(name => 'Product 200%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_and_code_name_cdbi GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = ($p->code_names)[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_CDBS:
  {
    my $printed = 0;

    sub search_simple_product_and_category_and_code_name_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Simple::Product->search(
        { name => { -like => [ 'Product 200%' ] } },
        { prefetch => [ 'category_id' ] });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_and_code_name_cdbs GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = ($p->code_names)[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_SIMPLE_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_DBIC:
  {
    my $printed = 0;

    sub search_simple_product_and_category_and_code_name_dbic
    {
      my @p = MyTest::DBIC::Simple::Product->search_like({ name => 'Product 200%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_simple_product_and_category_and_code_name_dbic GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $rs = $p->code_names;
        my $cn = $rs->next;
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  #
  # Search with limit and offset
  #

  use constant LIMIT  => 20;
  use constant OFFSET => 100;

  SEARCH_LIMIT_OFFSET_SIMPLE_PRODUCT_DBI:
  {
    my $printed = 0;

    sub search_limit_offset_simple_product_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  id,
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3,
  published,
  last_modified,
  date_created,
  id,
  name
FROM
  rose_db_object_test_products
WHERE
  name LIKE 'Product %2%'
LIMIT @{[LIMIT]} OFFSET @{[OFFSET]}
EOF

      $sth->execute;
      my $ps = $sth->fetchall_arrayref;

      if($Debug && !$printed)
      {
        print "search_limit_offset_simple_product_dbi GOT ", scalar(@$ps), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_SIMPLE_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub search_limit_offset_simple_product_rdbo
    {
      my $p =
        MyTest::RDBO::Simple::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            name => { like => 'Product %2%' },
          ],
          limit  => LIMIT,
          offset => OFFSET);
      #die unless(@$p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_simple_product_rdbo GOT ", scalar(@$p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_SIMPLE_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub search_limit_offset_simple_product_cdbi
    {
      die "Unsupported";
      my @p = MyTest::CDBI::Simple::Product->search_like(name => 'Product %2%');
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_simple_product_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_SIMPLE_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub search_limit_offset_simple_product_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Simple::Product->search_like(
        { name => 'Product %2%' }, { rows => LIMIT, offset => OFFSET });
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_simple_product_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_SIMPLE_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub search_limit_offset_simple_product_dbic
    {
      my @p = MyTest::DBIC::Simple::Product->search_like(
        { name => 'Product %2%' }, { rows => LIMIT, offset => OFFSET });
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_simple_product_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  #
  # Iterate
  #

  ITERATE_SIMPLE_CATEGORY_DBI:
  {
    my $printed = 0;

    sub iterate_simple_category_dbi
    {
      my $sth = $DBH->prepare("SELECT id, name FROM rose_db_object_test_categories WHERE name LIKE 'xCat %2%'");
      $sth->execute;
      my($id, $name);
      $sth->bind_columns(\$id, \$name);

      my $i = 0;

      while($sth->fetch)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_category_dbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub iterate_simple_category_rdbo
    {
      my $iter = 
        MyTest::RDBO::Simple::Category::Manager->get_categories_iterator(
          db => $DB,
          query =>
          [
            name => { like => 'xCat %2%' },
          ]);

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_category_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub iterate_simple_category_cdbi
    {
      my $iter = MyTest::CDBI::Simple::Category->search_like(name => 'xCat %2%');

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_category_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub iterate_simple_category_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Simple::Category->search_like(name => 'xCat %2%');

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_category_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub iterate_simple_category_dbic
    {
      my $iter = MyTest::DBIC::Simple::Category->search_like({ name => 'xCat %2%' });

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_category_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_DBI:
  {
    my $printed = 0;

    sub iterate_simple_product_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  id,
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3,
  published,
  last_modified,
  date_created
FROM
  rose_db_object_test_products
WHERE
  name LIKE 'Product %2%'
EOF
      $sth->execute;
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published last_modified date_created)});

      my $i = 0;

      while($sth->fetch)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_dbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub iterate_simple_product_rdbo
    {
      my $iter =
        MyTest::RDBO::Simple::Product::Manager->get_products_iterator(
          db => $DB,
          query =>
          [
            'name' => { like => 'Product %2%' },
          ]);

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub iterate_simple_product_cdbi
    {
      my $iter = MyTest::CDBI::Simple::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub iterate_simple_product_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Simple::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub iterate_simple_product_dbic
    {
      my $iter = MyTest::DBIC::Simple::Product->search_like({ name => 'Product %2%' });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_AND_CATEGORY_DBI:
  {
    my $printed = 0;

    sub iterate_simple_product_and_category_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  p.id,
  p.name,
  p.category_id,
  p.status,
  p.fk1,
  p.fk2,
  p.fk3,
  p.published,
  p.last_modified,
  p.date_created,
  c.id,
  c.name
FROM
  rose_db_object_test_products p,
  rose_db_object_test_categories c
WHERE
  c.id = p.category_id AND
  p.name LIKE 'Product %2%'
EOF

      $sth->execute;
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published
                                  last_modified date_created cat_id cat_name)});

      my $i = 0;

      while($sth->fetch)
      {
        $i++;
        my $n = $row{'cat_name'};
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_and_category_dbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub iterate_simple_product_and_category_rdbo
    {
      my $iter =
        MyTest::RDBO::Simple::Product::Manager->get_products_iterator(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product %2%' },
          ],
          with_objects => [ 'category' ]);

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_and_category_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub iterate_simple_product_and_category_cdbi
    {
      my $iter = MyTest::CDBI::Simple::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_and_category_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub iterate_simple_product_and_category_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Simple::Product->search(
        { name => { -like => [ 'Product %2%' ] } },
        { prefetch => [ 'category_id' ] });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_and_category_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_SIMPLE_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub iterate_simple_product_and_category_dbic
    {
      my $iter = MyTest::DBIC::Simple::Product->search_like({ name => 'Product %2%' });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_simple_product_and_category_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  #
  # Delete
  #

  DELETE_SIMPLE_CATEGORY_DBI:
  {
    my $i = 1;

    sub delete_simple_category_dbi
    {
      my $sth = $DBH->prepare('DELETE FROM rose_db_object_test_categories WHERE id = ?');
      $sth->execute($i + 500_000);
      $i++;
    }
  }

  DELETE_SIMPLE_CATEGORY_RDBO:
  {
    my $i = 1;

    sub delete_simple_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Simple::Category->new(
          db => $DB, 
          id => $i + 100_000);
      $c->delete;
      $i++;
    }
  }

  DELETE_SIMPLE_CATEGORY_CDBI:
  {
    my $i = 1;

    sub delete_simple_category_cdbi
    {
      my $c = MyTest::CDBI::Simple::Category->retrieve($i + 200_000);
      $c->delete;
      $i++;
    }
  }

  DELETE_SIMPLE_CATEGORY_CDBS:
  {
    my $i = 1;

    sub delete_simple_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Simple::Category->retrieve($i + 400_000);
      $c->delete;
      $i++;
    }
  }

  DELETE_SIMPLE_CATEGORY_DBIC:
  {
    my $i = 1;

    sub delete_simple_category_dbic
    {
      my $c = MyTest::DBIC::Simple::Category->find($i + 300_000);
      $c->delete;
      $i++;
    }
  }

  ##
  ## Complex
  ##

  #
  # Insert
  #

  # Using simple classes for some insert benchmarks because the complex
  # case for Rose::DB::Object differsw substantially in functionality from
  # the others.  RDBO parses column values in the constructor, whereas the
  # others require that column values be formatted correctly for the
  # current database ahead of time.

  INSERT_COMPLEX_CATEGORY_RDBO:
  {
    my $i = 1;

    sub insert_complex_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Complex::Category->new(
          db   => $DB, 
          id   => $i + 1_100_000, 
          name => "xCat $i");
      $c->save;
      $i++;
    }
  }

  INSERT_COMPLEX_CATEGORY_CDBI:
  {
    my $i = 1;

    sub insert_complex_category_cdbi
    {
      MyTest::CDBI::Complex::Category->create({ id => $i + 2_200_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_COMPLEX_CATEGORY_CDBS:
  {
    my $i = 1;

    sub insert_complex_category_cdbs
    {
      MyTest::CDBI::Sweet::Complex::Category->create({ id => $i + 4_400_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_COMPLEX_CATEGORY_DBIC:
  {
    my $i = 1;

    sub insert_complex_category_dbic
    {
      MyTest::DBIC::Complex::Category->create({ id => $i + 3_300_000, name => "xCat $i" });
      $i++;
    }
  }

  INSERT_COMPLEX_PRODUCT_RDBO:
  {
    my $i = 1;

    sub insert_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db           => $DB, 
          id           => $i + 1_100_000, 
          name         => "Product $i",
          category_id  => 2,
          status       => 'temp',
          published    => '2005-01-02 12:34:56');
      $p->save;
      $i++;
    }
  }

  INSERT_COMPLEX_PRODUCT_CDBI:
  {
    my $i = 1;

    sub insert_complex_product_cdbi
    {
      MyTest::CDBI::Complex::Product->create({
        id           => $i + 2_200_000, 
        name         => "Product $i",
        category_id  => 2,
        status       => 'temp',
        published    => '2005-01-02 12:34:56' });
      $i++;
    }
  }

  INSERT_COMPLEX_PRODUCT_CDBS:
  {
    my $i = 1;

    sub insert_complex_product_cdbs
    {
      MyTest::CDBI::Sweet::Complex::Product->create({
        id           => $i + 4_400_000, 
        name         => "Product $i",
        category_id  => 2,
        status       => 'temp',
        published    => '2005-01-02 12:34:56' });
      $i++;
    }
  }

  INSERT_COMPLEX_PRODUCT_DBIC:
  {
    my $i = 1;

    sub insert_complex_product_dbic
    {
      MyTest::DBIC::Complex::Product->create({
        id          => $i + 3_300_000, 
        name        => "Product $i",
        category_id => 2,
        status      => 'temp',
        published   => '2005-01-02 12:34:56' });
      $i++;
    }
  }

  #
  # Accessor
  #

  ACCCESSOR_COMPLEX_CATEGORY_RDBO:
  {
    sub accessor_complex_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Complex::Category->new(
          db  => $DB,
          id  => 1 + 100_000);

      $c->load;

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_CATEGORY_CDBI:
  {
    sub accessor_complex_category_cdbi
    {
      my $c = MyTest::CDBI::Complex::Category->retrieve(1 + 200_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_CATEGORY_CDBS:
  {
    sub accessor_complex_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Category->retrieve(1 + 400_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_CATEGORY_DBIC:
  {
    sub accessor_complex_category_dbic
    {
      my $c = MyTest::DBIC::Complex::Category->find(1 + 300_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name))
        {
          $c->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_PRODUCT_RDBO:
  {
    sub accessor_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db => $DB, 
          id => 1 + 100_000);

      $p->load;

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_PRODUCT_CDBI:
  {
    sub accessor_complex_product_cdbi
    {
      my $p = MyTest::CDBI::Complex::Product->retrieve(1 + 200_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_PRODUCT_CDBS:
  {
    sub accessor_complex_product_cdbs
    {
      my $p = MyTest::CDBI::Sweet::Complex::Product->retrieve(1 + 400_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  ACCCESSOR_COMPLEX_PRODUCT_DBIC:
  {
    sub accessor_complex_product_dbic
    {
      my $p = MyTest::DBIC::Complex::Product->find(1 + 300_000);

      for(1 .. ACCESSOR_ITERATIONS)
      {
        for(qw(id name status fk1 fk2 fk3 published last_modified
               date_created))
        {
          $p->$_();
        }
      }
    }
  }

  #
  # Load
  #

  LOAD_COMPLEX_CATEGORY_RDBO:
  {
    my $i = 1;

    sub load_complex_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Complex::Category->new(
          db => $DB, 
          id => $i + 1_100_000);
      $c->load;
      $i++;
    }
  }

  LOAD_COMPLEX_CATEGORY_CDBI:
  {
    my $i = 1;

    sub load_complex_category_cdbi
    {
      my $c = MyTest::CDBI::Complex::Category->retrieve($i + 2_200_000);
      $i++;
    }
  }

  LOAD_COMPLEX_CATEGORY_CDBS:
  {
    my $i = 1;

    sub load_complex_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Category->retrieve($i + 4_400_000);
      $i++;
    }
  }

  LOAD_COMPLEX_CATEGORY_DBIC:
  {
    my $i = 1;

    sub load_complex_category_dbic
    {
      my $c = MyTest::DBIC::Complex::Category->find($i + 3_300_000);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_RDBO:
  {
    my $i = 1;

    sub load_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db => $DB, 
          id => $i + 1_100_000);
      $p->load;
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_CDBI:
  {
    my $i = 1;

    sub load_complex_product_cdbi
    {
      my $c = MyTest::CDBI::Complex::Product->retrieve($i + 2_200_000);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_CDBS:
  {
    my $i = 1;

    sub load_complex_product_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Product->retrieve($i + 4_400_000);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_DBIC:
  {
    my $i = 1;

    sub load_complex_product_dbic
    {
      my $c = MyTest::DBIC::Complex::Product->find($i + 3_300_000);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $i = 1;

    sub load_complex_product_and_category_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db => $DB, 
          id => $i + 1_100_000);
      $p->load;

      my $cat = $p->category;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $i = 1;

    sub load_complex_product_and_category_cdbi
    {
      my $c = MyTest::CDBI::Complex::Product->retrieve($i + 2_200_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $i = 1;

    sub load_complex_product_and_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Product->retrieve($i + 4_400_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  LOAD_COMPLEX_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $i = 1;

    sub load_complex_product_and_category_dbic
    {
      my $c = MyTest::DBIC::Complex::Product->find($i + 3_300_000);
      my $cat = $c->category_id;
      my $n = $cat->name;
      die  unless($n =~ /\S/);
      $i++;
    }
  }

  #
  # Update
  #

  UPDATE_COMPLEX_CATEGORY_RDBO:
  {
    my $i = 1;

    sub update_complex_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Complex::Category->new(
          db => $DB, 
          id => $i + 1_100_000);
      $c->load;
      $c->name($c->name . ' updated');
      $c->save;
      $i++;
    }
  }

  UPDATE_COMPLEX_CATEGORY_CDBI:
  {
    my $i = 1;

    sub update_complex_category_cdbi
    {
      my $c = MyTest::CDBI::Complex::Category->retrieve($i + 2_200_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_COMPLEX_CATEGORY_CDBS:
  {
    my $i = 1;

    sub update_complex_category_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Category->retrieve($i + 4_400_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_COMPLEX_CATEGORY_DBIC:
  {
    my $i = 1;

    sub update_complex_category_dbic
    {
      my $c = MyTest::DBIC::Complex::Category->find($i + 3_300_000);
      $c->name($c->name . ' updated');
      $c->update;
      $i++;
    }
  }

  UPDATE_COMPLEX_PRODUCT_RDBO:
  {
    my $i = 1;

    sub update_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db => $DB, 
          id => $i + 1_100_000);
      $p->load;
      $p->name($p->name . ' updated');

      # These state calls give over a 100% speed boost, but they're a bit
      # inappropriate since no one is going to use them in practice.  OTOH,
      # none of the other modules validate their input, so I reserve the
      # right to uncomment them for a better "apples to apples" comparison
      # in the future :)
      #set_state_loading($p);
      $p->published('2004-01-02 12:34:55');
      #unset_state_loading($p);

      $p->save;
      $i++;
    }
  }

  UPDATE_COMPLEX_PRODUCT_CDBI:
  {
    my $i = 1;

    sub update_complex_product_cdbi
    {
      my $p = MyTest::CDBI::Complex::Product->retrieve($i + 2_200_000);
      $p->name($p->name . ' updated');
      $p->published('2004-01-02 12:34:55');
      $p->update;
      $i++;
    }
  }

  UPDATE_COMPLEX_PRODUCT_CDBS:
  {
    my $i = 1;

    sub update_complex_product_cdbs
    {
      my $p = MyTest::CDBI::Sweet::Complex::Product->retrieve($i + 4_400_000);
      $p->name($p->name . ' updated');
      $p->published('2004-01-02 12:34:55');
      $p->update;
      $i++;
    }
  }

  UPDATE_COMPLEX_PRODUCT_DBIC:
  {
    my $i = 1;

    sub update_complex_product_dbic
    {
      my $p = MyTest::DBIC::Complex::Product->find($i + 3_300_000);
      $p->name($p->name . ' updated');
      $p->published('2004-01-02 12:34:55');
      $p->update;
      $i++;
    }
  }

  #
  # Search
  #

  SEARCH_COMPLEX_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub search_complex_category_rdbo
    {
      my $c = 
        MyTest::RDBO::Complex::Category::Manager->get_categories(
          db => $DB,
          query =>
          [
            name => { like => 'xCat %2%' },
          ]);
      die unless(@$c);

      if($Debug && !$printed)
      {
        print "search_complex_category_rdbo GOT ", scalar(@$c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub search_complex_category_cdbi
    {
      my @c = MyTest::CDBI::Complex::Category->search_like(name => 'xCat %2%');
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_complex_category_cdbi GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub search_complex_category_cdbs
    {
      my @c = MyTest::CDBI::Sweet::Complex::Category->search_like(name => 'xCat %2%');
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_complex_category_cdbs GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub search_complex_category_dbic
    {
      my @c = MyTest::DBIC::Complex::Category->search_like({ name => 'xCat %2%' });
      die unless(@c);

      if($Debug && !$printed)
      {
        print "search_complex_category_dbic GOT ", scalar(@c), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub search_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            name => { like => 'Product %2%' },
          ]);
      die unless(@$p);

      if($Debug && !$printed)
      {
        print "search_complex_product_rdbo GOT ", scalar(@$p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub search_complex_product_cdbi
    {
      my @p = MyTest::CDBI::Complex::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub search_complex_product_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Complex::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub search_complex_product_dbic
    {
      my @p = MyTest::DBIC::Complex::Product->search_like({ name => 'Product %2%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub search_complex_product_and_category_rdbo
    {
      my $ps =
        MyTest::RDBO::Complex::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product %2%' },
          ],
          with_objects => [ 'category' ]);
      die unless(@$ps);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_rdbo GOT ", scalar(@$ps), "\n";
        $printed++;
      }

      foreach my $p (@$ps)
      {
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub search_complex_product_and_category_cdbi
    {
      my @p = MyTest::CDBI::Complex::Product->search_like(name => 'Product %2%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub search_complex_product_and_category_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Complex::Product->search(
        { name => { -like => [ 'Product %2%' ] } },
        { prefetch => [ 'category_id' ] });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub search_complex_product_and_category_dbic
    {
      my @p = MyTest::DBIC::Complex::Product->search_like({ name => 'Product %2%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }
    }
  }

  #
  # Search with 1-to-1 and 1-to-n sub-objects
  #

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_DBI:
  {
    my $printed = 0;

    sub search_complex_product_and_category_and_code_name_dbi
    {
      my $sth = $DBH->prepare(<<"EOF");
SELECT
  p.id,
  p.name,
  p.category_id,
  p.status,
  p.fk1,
  p.fk2,
  p.fk3,
  p.published,
  p.last_modified,
  p.date_created,
  c.id,
  c.name,
  n.id, 
  n.product_id,
  n.name
FROM
  rose_db_object_test_products p
  LEFT OUTER JOIN rose_db_object_test_code_names n ON(n.product_id = p.id),
  rose_db_object_test_categories c
WHERE
  c.id = p.category_id AND
  n.product_id = p.id AND
  p.name LIKE 'Product 200%'
EOF

      $sth->execute;
      my %row;
      $sth->bind_columns(\@row{qw(id name category_id status fk1 fk2 fk3 published
                                  last_modified date_created cat_id cat_name
                                  cn_id cn_product_id cn_name)});

      my @ps;

      while($sth->fetch)
      {
        push(@ps, { %row });
      }

      die unless(@ps);

      if($Debug && !$printed)
      {
        my(%seen, $num);

        foreach my $p (@ps)
        {
          $num++  unless($seen{$p->{'id'}}++);
        }

        print "search_complex_product_and_category_and_code_name_dbi GOT $num\n";
        #$printed++;
      }

      foreach my $p (@ps)
      {
        my $n = $p->{'cat_name'};
        die  unless($n =~ /\S/);
        my $cn = $p->{'cn_name'};
        die  unless($cn =~ /^CN /);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_RDBO:
  {
    my $printed = 0;

    sub search_complex_product_and_category_and_code_name_rdbo
    {
      #local $Rose::DB::Object::Manager::Debug = 1;
      my $ps =
        MyTest::RDBO::Complex::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product 200%' },
          ],
          with_objects    => [ 'code_names' ],
          require_objects => [ 'category' ]);
      die unless(@$ps);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_and_code_name_rdbo GOT ", scalar(@$ps), "\n";
        #$printed++;
      }

      foreach my $p (@$ps)
      {
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = $p->code_names->[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_CDBI:
  {
    my $printed = 0;

    sub search_complex_product_and_category_and_code_name_cdbi
    {
      my @p = MyTest::CDBI::Complex::Product->search_like(name => 'Product 200%');
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_and_code_name_cdbi GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = ($p->code_names)[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_CDBS:
  {
    my $printed = 0;

    sub search_complex_product_and_category_and_code_name_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Complex::Product->search(
        { name => { -like => [ 'Product 200%' ] } },
        { prefetch => [ 'category_id' ] });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_and_code_name_cdbs GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $cn = ($p->code_names)[0];
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  SEARCH_COMPLEX_PRODUCT_AND_CATEGORY_AND_CODE_NAMES_DBIC:
  {
    my $printed = 0;

    sub search_complex_product_and_category_and_code_name_dbic
    {
      my @p = MyTest::DBIC::Complex::Product->search_like({ name => 'Product 200%' });
      die unless(@p);

      if($Debug && !$printed)
      {
        print "search_complex_product_and_category_and_code_name_dbic GOT ", scalar(@p), "\n";
        #$printed++;
      }

      foreach my $p (@p)
      {
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
        my $rs = $p->code_names;
        my $cn = $rs->next;
        die  unless($cn->name =~ /^CN /);
      }
    }
  }

  #
  # Search with limit and offset
  #

  SEARCH_LIMIT_OFFSET_COMPLEX_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub search_limit_offset_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product::Manager->get_products(
          db => $DB,
          query =>
          [
            name => { like => 'Product %2%' },
          ],
          limit  => LIMIT,
          offset => OFFSET);
      #die unless(@$p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_complex_product_rdbo GOT ", scalar(@$p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_COMPLEX_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub search_limit_offset_complex_product_cdbi
    {
      die "Unsupported";
      my @p = MyTest::CDBI::Complex::Product->search_like(name => 'Product %2%');
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_complex_product_cdbi GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_COMPLEX_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub search_limit_offset_complex_product_cdbs
    {
      my @p = MyTest::CDBI::Sweet::Complex::Product->search_like(
        { name => 'Product %2%' }, { rows => LIMIT, offset => OFFSET });
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_complex_product_cdbs GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  SEARCH_LIMIT_OFFSET_COMPLEX_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub search_limit_offset_complex_product_dbic
    {
      my @p = MyTest::DBIC::Complex::Product->search_like(
        { name => 'Product %2%' }, { rows => LIMIT, offset => OFFSET });
      #die unless(@p);

      if($Debug && !$printed)
      {
        print "search_limit_offset_complex_product_dbic GOT ", scalar(@p), "\n";
        $printed++;
      }
    }
  }

  #
  # Iterate
  #

  ITERATE_COMPLEX_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub iterate_complex_category_rdbo
    {
      my $iter = 
        MyTest::RDBO::Complex::Category::Manager->get_categories_iterator(
          db => $DB,
          query =>
          [
            name => { like => 'xCat %2%' },
          ]);

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_category_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub iterate_complex_category_cdbi
    {
      my $iter = MyTest::CDBI::Complex::Category->search_like(name => 'xCat %2%');

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_category_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub iterate_complex_category_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Complex::Category->search_like(name => 'xCat %2%');

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_category_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub iterate_complex_category_dbic
    {
      my $iter = MyTest::DBIC::Complex::Category->search_like({ name => 'xCat %2%' });

      my $i = 0;

      while(my $c = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_category_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_RDBO:
  {
    my $printed = 0;

    sub iterate_complex_product_rdbo
    {
      my $iter =
        MyTest::RDBO::Complex::Product::Manager->get_products_iterator(
          db => $DB,
          query =>
          [
            'name' => { like => 'Product %2%' },
          ]);

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_CDBI:
  {
    my $printed = 0;

    sub iterate_complex_product_cdbi
    {
      my $iter = MyTest::CDBI::Complex::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_CDBS:
  {
    my $printed = 0;

    sub iterate_complex_product_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Complex::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_DBIC:
  {
    my $printed = 0;

    sub iterate_complex_product_dbic
    {
      my $iter = MyTest::DBIC::Complex::Product->search_like({ name => 'Product %2%' });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_AND_CATEGORY_RDBO:
  {
    my $printed = 0;

    sub iterate_complex_product_and_category_rdbo
    {
      my $iter =
        MyTest::RDBO::Complex::Product::Manager->get_products_iterator(
          db => $DB,
          query =>
          [
            't1.name' => { like => 'Product %2%' },
          ],
          with_objects => [ 'category' ]);

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_and_category_rdbo GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_AND_CATEGORY_CDBI:
  {
    my $printed = 0;

    sub iterate_complex_product_and_category_cdbi
    {
      my $iter = MyTest::CDBI::Complex::Product->search_like(name => 'Product %2%');

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_and_category_cdbi GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_AND_CATEGORY_CDBS:
  {
    my $printed = 0;

    sub iterate_complex_product_and_category_cdbs
    {
      my $iter = MyTest::CDBI::Sweet::Complex::Product->search(
        { name => { -like => [ 'Product %2%' ] } },
        { prefetch => [ 'category_id' ] });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_and_category_cdbs GOT $i\n";
        $printed++;
      }
    }
  }

  ITERATE_COMPLEX_PRODUCT_AND_CATEGORY_DBIC:
  {
    my $printed = 0;

    sub iterate_complex_product_and_category_dbic
    {
      my $iter = MyTest::DBIC::Complex::Product->search_like({ name => 'Product %2%' });

      my $i = 0;

      while(my $p = $iter->next)
      {
        $i++;
        my $cat = $p->category_id;
        my $n = $cat->name;
        die  unless($n =~ /\S/);
      }

      if($Debug && !$printed)
      {
        print "iterate_complex_product_and_category_dbic GOT $i\n";
        $printed++;
      }
    }
  }

  #
  # Delete
  #

  DELETE_COMPLEX_PRODUCT_DBI:
  {
    my $i = 1;

    sub delete_complex_product_dbi
    {
      my $sth = $DBH->prepare('DELETE FROM rose_db_object_test_products WHERE id = ?');
      $sth->execute($i + 500_000);
      $i++;
    }
  }

  DELETE_COMPLEX_PRODUCT_RDBO:
  {
    my $i = 1;

    sub delete_complex_product_rdbo
    {
      my $p =
        MyTest::RDBO::Complex::Product->new(
          db => $DB, 
          id => $i + 1_100_000);
      $p->delete;
      $i++;
    }
  }

  DELETE_COMPLEX_PRODUCT_CDBI:
  {
    my $i = 1;

    sub delete_complex_product_cdbi
    {
      my $c = MyTest::CDBI::Complex::Product->retrieve($i + 2_200_000);
      $c->delete;
      $i++;
    }
  }

  DELETE_COMPLEX_PRODUCT_CDBS:
  {
    my $i = 1;

    sub delete_complex_product_cdbs
    {
      my $c = MyTest::CDBI::Sweet::Complex::Product->retrieve($i + 4_400_000);
      $c->delete;
      $i++;
    }
  }

  DELETE_COMPLEX_PRODUCT_DBIC:
  {
    my $i = 1;

    sub delete_complex_product_dbic
    {
      my $c = MyTest::DBIC::Complex::Product->find($i + 3_300_000);
      $c->delete;
      $i++;
    }
  }
}

sub Bench
{
  my($name, $iterations, $tests, $no_newline) = @_;

  my %filtered_tests;

  my $db_regex = '\b(?:RDBO|' . join('|', map { $Cmp_Abbreviation{$_} } @Cmp_To) . ')\b';
  $db_regex = qr($db_regex);

  if(($name =~ /^Simple:/ &&  !($Opt{'simple'} || $Opt{'simple-and-complex'})) ||
     ($name =~ /^Complex:/ && !($Opt{'complex'} || $Opt{'simple-and-complex'})))
  {
    return;
  }

  while(my($test_name, $code) = each(%$tests))
  {
    next  unless($test_name =~ /$db_regex/);
    $filtered_tests{$test_name} = $code;
  }

  return  unless(%filtered_tests && (!$Bench_Match || $name =~ /$Bench_Match/));
  print "\n"  unless($no_newline);
  print "# $name\n";

  if($Opt{'time'} || $Opt{'time-and-compare'})
  {
    my $r = timethese($iterations, \%filtered_tests);
    cmpthese($r)  if($Opt{'time-and-compare'});
  }
  else
  {
    cmpthese($iterations, \%filtered_tests);
  }
}

sub Run_Tests
{
  #
  # Insert
  #

  Bench('Simple: insert 1', $Iterations,
  {
    'DBI ' => \&insert_simple_category_dbi,
    'RDBO' => \&insert_simple_category_rdbo,
    'CDBI' => \&insert_simple_category_cdbi,
    'CDBS' => \&insert_simple_category_cdbs,
    'DBIC' => \&insert_simple_category_dbic,
  }, 'no-newline');

  Bench('Complex: insert 1', $Iterations,
  {
    'DBI ' => \&insert_simple_category_dbi,
    'RDBO' => \&insert_complex_category_rdbo,
    'CDBI' => \&insert_complex_category_cdbi,
    'CDBS' => \&insert_complex_category_cdbs,
    'DBIC' => \&insert_complex_category_dbic,
  }, $Opt{'complex'} ? 'no-newline' : 0);

  Bench('Simple: insert 2', $Iterations,
  {
    'DBI ' => \&insert_simple_product_dbi,
    'RDBO' => \&insert_simple_product_rdbo,
    'CDBI' => \&insert_simple_product_cdbi,
    'CDBS' => \&insert_simple_product_cdbs,
    'DBIC' => \&insert_simple_product_dbic,
  });

  Bench('Complex: insert 2', $Iterations,
  {
    'DBI ' => \&insert_simple_product_dbi,
    'RDBO' => \&insert_complex_product_rdbo,
    'CDBI' => \&insert_complex_product_cdbi,
    'CDBS' => \&insert_complex_product_cdbs,
    'DBIC' => \&insert_complex_product_dbic,
  });

  INTERNAL_LOOPERS1:
  {
    #
    # Accessor
    #

    # It's okay for these tests to only have a few iterations because they
    # loop internally.
    local $Benchmark::Min_Count = 1;

    Bench('Simple: accessor 1', $CPU_Time,
    {
      'DBI ' => \&accessor_simple_category_dbi,
      'RDBO' => \&accessor_simple_category_rdbo,
      'CDBI' => \&accessor_simple_category_cdbi,
      'CDBS' => \&accessor_simple_category_cdbs,
      'DBIC' => \&accessor_simple_category_dbic,
    });

    Bench('Complex: accessor 1', $CPU_Time,
    {
      'DBI ' => \&accessor_simple_category_dbi,
      'RDBO' => \&accessor_complex_category_rdbo,
      'CDBI' => \&accessor_complex_category_cdbi,
      'CDBS' => \&accessor_complex_category_cdbs,
      'DBIC' => \&accessor_complex_category_dbic,
    });

    Bench('Simple: accessor 2', $CPU_Time,
    {
      'DBI ' => \&accessor_simple_product_dbi,
      'RDBO' => \&accessor_simple_product_rdbo,
      'CDBI' => \&accessor_simple_product_cdbi,
      'CDBS' => \&accessor_simple_product_cdbs,
      'DBIC' => \&accessor_simple_product_dbic,
    });

    Bench('Complex: accessor 2', $CPU_Time,
    {
      'DBI ' => \&accessor_simple_product_dbi,
      'RDBO' => \&accessor_complex_product_rdbo,
      'CDBI' => \&accessor_complex_product_cdbi,
      'CDBS' => \&accessor_complex_product_cdbs,
      'DBIC' => \&accessor_complex_product_dbic,
    });
  }

  #
  # Load
  #

  Bench('Simple: load 1', $Iterations,
  {
    'DBI ' => \&load_simple_category_dbi,
    'RDBO' => \&load_simple_category_rdbo,
    'CDBI' => \&load_simple_category_cdbi,
    'CDBS' => \&load_simple_category_cdbs,
    'DBIC' => \&load_simple_category_dbic,
  });

  #Bench('Complex: load 1', $Iterations,
  #{
  #  'RDBO' => \&load_complex_category_rdbo,
  #  'CDBI' => \&load_complex_category_cdbi,
  #  'CDBS' => \&load_complex_category_cdbs,
  #  'DBIC' => \&load_complex_category_dbic,
  #});

  Bench('Simple: load 2', $Iterations,
  {
    'DBI ' => \&load_simple_product_dbi,
    'RDBO' => \&load_simple_product_rdbo,
    'CDBI' => \&load_simple_product_cdbi,
    'CDBS' => \&load_simple_product_cdbs,
    'DBIC' => \&load_simple_product_dbic,
  });

  Bench('Complex: load 2', $Iterations,
  {
    'DBI ' => \&load_simple_product_dbi,
    'RDBO' => \&load_complex_product_rdbo,
    'CDBI' => \&load_complex_product_cdbi,
    'CDBS' => \&load_complex_product_cdbs,
    'DBIC' => \&load_complex_product_dbic,
  });

  Bench('Simple: load 3', $Iterations,
  {
    'DBI ' => \&load_simple_product_and_category_dbi,
    'RDBO' => \&load_simple_product_and_category_rdbo,
    'CDBI' => \&load_simple_product_and_category_cdbi,
    'CDBS' => \&load_simple_product_and_category_cdbs,
    'DBIC' => \&load_simple_product_and_category_dbic,
  });

  Bench('Complex: load 3', $Iterations,
  {
    'DBI ' => \&load_simple_product_and_category_dbi,
    'RDBO' => \&load_complex_product_and_category_rdbo,
    'CDBI' => \&load_complex_product_and_category_cdbi,
    'CDBS' => \&load_complex_product_and_category_cdbs,
    'DBIC' => \&load_complex_product_and_category_dbic,
  });

  #
  # Update
  #

  Bench('Simple: update 1', $Iterations,
  {
    'DBI ' => \&update_simple_category_dbi,
    'RDBO' => \&update_simple_category_rdbo,
    'CDBI' => \&update_simple_category_cdbi,
    'CDBS' => \&update_simple_category_cdbs,
    'DBIC' => \&update_simple_category_dbic,
  });

  #Bench('Complex: update 1', $Iterations,
  #{
  #  'RDBO' => \&update_complex_category_rdbo,
  #  'CDBI' => \&update_complex_category_cdbi,
  #  'CDBS' => \&update_complex_category_cdbs,
  #  'DBIC' => \&update_complex_category_dbic,
  #});

  Bench('Simple: update 2', $Iterations,
  {
    'DBI ' => \&update_simple_product_dbi,
    'RDBO' => \&update_simple_product_rdbo,
    'CDBI' => \&update_simple_product_cdbi,
    'CDBS' => \&update_simple_product_cdbs,
    'DBIC' => \&update_simple_product_dbic,
  });

  Bench('Complex: update 2', $Iterations,
  {
    'DBI ' => \&update_simple_product_dbi,
    'RDBO' => \&update_complex_product_rdbo,
    'CDBI' => \&update_complex_product_cdbi,
    'CDBS' => \&update_complex_product_cdbs,
    'DBIC' => \&update_complex_product_dbic,
  });

  INTERNAL_LOOPERS2:
  {
    #
    # Search
    #

    # It's okay for these tests to only have a few iterations because they
    # loop internally.
    local $Benchmark::Min_Count = 1;

    Bench('Simple: search 1', $CPU_Time,
    {
      'DBI ' => \&search_simple_category_dbi,
      'RDBO' => \&search_simple_category_rdbo,
      'CDBI' => \&search_simple_category_cdbi,
      'CDBS' => \&search_simple_category_cdbs,
      'DBIC' => \&search_simple_category_dbic,
    });

    #Bench('Complex: search 1', $CPU_Time,
    #{
    #  'DBI ' => \&search_simple_category_dbi,
    #  'RDBO' => \&search_complex_category_rdbo,
    #  'CDBI' => \&search_complex_category_cdbi,
    #  'CDBS' => \&search_complex_category_cdbs,
    #  'DBIC' => \&search_complex_category_dbic,
    #});

    Bench('Simple: search 2', $CPU_Time,
    {
      'DBI ' => \&search_simple_product_dbi,
      'RDBO' => \&search_simple_product_rdbo,
      'CDBI' => \&search_simple_product_cdbi,
      'CDBS' => \&search_simple_product_cdbs,
      'DBIC' => \&search_simple_product_dbic,
    });

    Bench('Complex: search 2', $CPU_Time,
    {
      'DBI ' => \&search_simple_product_dbi,
      'RDBO' => \&search_complex_product_rdbo,
      'CDBI' => \&search_complex_product_cdbi,
      'CDBS' => \&search_complex_product_cdbs,
      'DBIC' => \&search_complex_product_dbic,
    });

    Bench('Simple: search with limit and offset', $CPU_Time,
    {
      'DBI ' => \&search_limit_offset_simple_product_dbi,
      'RDBO' => \&search_limit_offset_simple_product_rdbo,
      #'CDBI' => \&search_limit_offset_simple_product_cdbi,
      'CDBS' => \&search_limit_offset_simple_product_cdbs,
      'DBIC' => \&search_limit_offset_simple_product_dbic,
    });

    Bench('Complex: search with limit and offset', $CPU_Time,
    {
      'DBI ' => \&search_limit_offset_simple_product_dbi,
      'RDBO' => \&search_limit_offset_complex_product_rdbo,
      #'CDBI' => \&search_limit_offset_complex_product_cdbi,
      'CDBS' => \&search_limit_offset_complex_product_cdbs,
      'DBIC' => \&search_limit_offset_complex_product_dbic,
    });

    Make_Indexes();

    Bench('Simple: search with 1-to-1 sub-objects', $CPU_Time,
    {
      'DBI ' => \&search_simple_product_and_category_dbi,
      'RDBO' => \&search_simple_product_and_category_rdbo,
      'CDBI' => \&search_simple_product_and_category_cdbi,
      'CDBS' => \&search_simple_product_and_category_cdbs,
      'DBIC' => \&search_simple_product_and_category_dbic,
    });

    Bench('Complex: search with 1-to-1 sub-objects', $CPU_Time ,
    {
      'DBI ' => \&search_simple_product_and_category_dbi,
      'RDBO' => \&search_complex_product_and_category_rdbo,
      'CDBI' => \&search_complex_product_and_category_cdbi,
      'CDBS' => \&search_complex_product_and_category_cdbs,
      'DBIC' => \&search_complex_product_and_category_dbic,
    });

    Insert_Code_Names(); # no reason to bench this

    CPU_MISERS:
    {
      local $Benchmark::Min_Count = 0;
      local $Benchmark::Min_CPU   = 0;

      # These tests take forever (wallclock), even when set to 1 CPU
      # second.  Force a reasonable number of iterations, scaled
      # coarsely based on how many iterations other tests are using.

      my $Tiny_Interations = $Iterations <= 1000 ? 5 :
                             $Iterations <= 3000 ? 2 :
                             $Iterations <= 5000 ? 1 :
                                                   1;

      Bench('Simple: search with 1-to-1 and 1-to-n sub-objects', $Tiny_Interations,
      {
        'DBI ' => \&search_simple_product_and_category_and_code_name_dbi,
        'RDBO' => \&search_simple_product_and_category_and_code_name_rdbo,
        'CDBI' => \&search_simple_product_and_category_and_code_name_cdbi,
        'CDBS' => \&search_simple_product_and_category_and_code_name_cdbs,
        'DBIC' => \&search_simple_product_and_category_and_code_name_dbic,
      });

      Bench('Complex: search with 1-to-1 and 1-to-n sub-objects', $Tiny_Interations,
      {
        'DBI ' => \&search_complex_product_and_category_and_code_name_dbi,
        'RDBO' => \&search_complex_product_and_category_and_code_name_rdbo,
        'CDBI' => \&search_complex_product_and_category_and_code_name_cdbi,
        'CDBS' => \&search_complex_product_and_category_and_code_name_cdbs,
        'DBIC' => \&search_complex_product_and_category_and_code_name_dbic,
      });
    }

    #
    # Iterate
    #

    Bench('Simple: iterate 1', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_category_dbi,
      'RDBO' => \&iterate_simple_category_rdbo,
      'CDBI' => \&iterate_simple_category_cdbi,
      'CDBS' => \&iterate_simple_category_cdbs,
      'DBIC' => \&iterate_simple_category_dbic,
    });

    Bench('Complex: iterate 1', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_category_dbi,
      'RDBO' => \&iterate_complex_category_rdbo,
      'CDBI' => \&iterate_complex_category_cdbi,
      'CDBS' => \&iterate_complex_category_cdbs,
      'DBIC' => \&iterate_complex_category_dbic,
    });

    Bench('Simple: iterate 2', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_product_dbi,
      'RDBO' => \&iterate_simple_product_rdbo,
      'CDBI' => \&iterate_simple_product_cdbi,
      'CDBS' => \&iterate_simple_product_cdbs,
      'DBIC' => \&iterate_simple_product_dbic,
    });

    Bench('Complex: iterate 2', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_product_dbi,
      'RDBO' => \&iterate_complex_product_rdbo,
      'CDBI' => \&iterate_complex_product_cdbi,
      'CDBS' => \&iterate_complex_product_cdbs,
      'DBIC' => \&iterate_complex_product_dbic,
    });

    Bench('Simple: iterate 3', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_product_and_category_dbi,
      'RDBO' => \&iterate_simple_product_and_category_rdbo,
      'CDBI' => \&iterate_simple_product_and_category_cdbi,
      'CDBS' => \&iterate_simple_product_and_category_cdbs,
      'DBIC' => \&iterate_simple_product_and_category_dbic,
    });

    Bench('Complex: iterate 3', $CPU_Time,
    {
      'DBI ' => \&iterate_simple_product_and_category_dbi,
      'RDBO' => \&iterate_complex_product_and_category_rdbo,
      'CDBI' => \&iterate_complex_product_and_category_cdbi,
      'CDBS' => \&iterate_complex_product_and_category_cdbs,
      'DBIC' => \&iterate_complex_product_and_category_dbic,
    });
  }

  #
  # Delete
  #

  Drop_Indexes();

  Bench('Simple: delete', $Iterations,
  {
    'DBI ' => \&delete_simple_category_dbi,
    'RDBO' => \&delete_simple_category_rdbo,
    'CDBI' => \&delete_simple_category_cdbi,
    'CDBS' => \&delete_simple_category_cdbs,
    'DBIC' => \&delete_simple_category_dbic,
  });

  Bench('Complex: delete', $Iterations,
  {
    'DBI ' => \&delete_complex_product_dbi,
    'RDBO' => \&delete_complex_product_rdbo,
    'CDBI' => \&delete_complex_product_cdbi,
    'CDBS' => \&delete_complex_product_cdbs,
    'DBIC' => \&delete_complex_product_dbic,
  });

  $DB && $DB->disconnect;
}

sub Check_DB
{
  my $dbh;

  # Postgres

  eval 
  {
    $dbh = Rose::DB->new('pg')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have_DB{'pg'} = 1;
  }

  # MySQL

  eval 
  {
    $dbh = Rose::DB->new('mysql')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have_DB{'mysql'} = 1;
  }

  # Informix

  eval 
  {
    $dbh = Rose::DB->new('informix')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have_DB{'informix'} = 1;
  }

  @Use_DBs = sort keys %Have_DB;
}

sub Init_DB
{
  my %init = map { $_ => 1 } @Use_DBs;
  my $dbh;

  foreach my $to_init (@Use_DBs)
  {
    unless($Have_DB{$to_init})
    {
      die "*** ERROR: Cannot connect to database: $to_init\n";
    }
  }

  #
  # Postgres
  #

  if($init{'pg'})
  {
    $dbh = Rose::DB->new('pg')->retain_dbh()
      or die Rose::DB->error;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test_code_names');
      $dbh->do('DROP TABLE rose_db_object_test_products');
      $dbh->do('DROP TABLE rose_db_object_test_categories');
      $dbh->do('DROP TABLE rose_db_object_test_codes');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_codes
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  code  VARCHAR(32),

  PRIMARY KEY(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_categories
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_products
(
  id             SERIAL PRIMARY KEY,
  name           VARCHAR(255) NOT NULL,
  category_id    INT REFERENCES rose_db_object_test_categories (id),
  status         VARCHAR(32) DEFAULT 'active',
  fk1            INT,
  fk2            INT,
  fk3            INT,
  published      TIMESTAMP,
  last_modified  TIMESTAMP DEFAULT NOW(),
  date_created   TIMESTAMP DEFAULT NOW(),

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_test_codes (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_code_names
(
  id          SERIAL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES rose_db_object_test_products (id),
  name        VARCHAR(32)
)
EOF

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_codes (k1, k2, k3, code) VALUES
  ($i, @{[$i + 1]}, @{[$i + 2]}, 'MYCODE$i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_categories (name) VALUES ('Cat $i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_products
(
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3
)
VALUES
(
  'Product $i',
  $i,
  '@{[ rand > .25 ? 'active' : 'disabled' ]}',
  $i,
  @{[$i + 1]},
  @{[$i + 2]}
)
EOF
    }

    $dbh->disconnect;

    $Inited_DB{'pg'} = 1;
  }

  #
  # MySQL
  #

  if($init{'mysql'})
  {
    $dbh = Rose::DB->new('mysql')->retain_dbh()
      or die Rose::DB->error;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test_code_names');
      $dbh->do('DROP TABLE rose_db_object_test_products');
      $dbh->do('DROP TABLE rose_db_object_test_categories');
      $dbh->do('DROP TABLE rose_db_object_test_codes');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_codes
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  code  VARCHAR(32),

  PRIMARY KEY(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_categories
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_products
(
  id             INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(255) NOT NULL,
  category_id    INT REFERENCES rose_db_object_test_categories (id),
  status         VARCHAR(32) DEFAULT 'active',
  fk1            INT,
  fk2            INT,
  fk3            INT,
  published      DATETIME,
  last_modified  DATETIME,
  date_created   DATETIME
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_code_names
(
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES rose_db_object_test_products (id),
  name        VARCHAR(32)
)
EOF

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_codes (k1, k2, k3, code) VALUES
  ($i, @{[$i + 1]}, @{[$i + 2]}, 'MYCODE$i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_categories (name) VALUES ('Cat $i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_products
(
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3
)
VALUES
(
  'Product $i',
  $i,
  '@{[ rand > .25 ? 'active' : 'disabled' ]}',
  $i,
  @{[$i + 1]},
  @{[$i + 2]}
)
EOF
    }

    $Inited_DB{'mysql'} = 1;
  }

  #
  # Informix
  #

  if($init{'informix'})
  {
    $dbh = Rose::DB->new('informix')->retain_dbh()
      or die Rose::DB->error;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test_code_names');
      $dbh->do('DROP TABLE rose_db_object_test_products');
      $dbh->do('DROP TABLE rose_db_object_test_categories');
      $dbh->do('DROP TABLE rose_db_object_test_codes');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_codes
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  code  VARCHAR(32),

  PRIMARY KEY(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_categories
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_products
(
  id             SERIAL PRIMARY KEY,
  name           VARCHAR(255) NOT NULL,
  category_id    INT REFERENCES rose_db_object_test_categories (id),
  status         VARCHAR(32) DEFAULT 'active',
  fk1            INT,
  fk2            INT,
  fk3            INT,
  published      DATETIME YEAR TO SECOND,
  last_modified  DATETIME YEAR TO SECOND,
  date_created   DATETIME YEAR TO SECOND,

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_test_codes (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test_code_names
(
  id          SERIAL PRIMARY KEY,
  product_id  INT NOT NULL REFERENCES rose_db_object_test_products (id),
  name        VARCHAR(32)
)
EOF

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_codes (k1, k2, k3, code) VALUES
  ($i, @{[$i + 1]}, @{[$i + 2]}, 'MYCODE$i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_categories (name) VALUES ('Cat $i')
EOF
    }

    foreach my $i (1 .. 10)
    {
      $dbh->do(<<"EOF");
INSERT INTO rose_db_object_test_products
(
  name,
  category_id,
  status,
  fk1,
  fk2,
  fk3
)
VALUES
(
  'Product $i',
  $i,
  '@{[ rand > .25 ? 'active' : 'disabled' ]}',
  $i,
  @{[$i + 1]},
  @{[$i + 2]}
)
EOF
    }

    $Inited_DB{'informix'} = 1;
  }
}

END
{
  $DB && $DB->disconnect;

  if($MyTest::CDBI::Base::DB)
  {
    $MyTest::CDBI::Base::DB = undef;
    MyTest::CDBI::Base->db_Main->disconnect;
  }

  if($MyTest::CDBI::Sweet::Base::DB)
  {
    $MyTest::CDBI::Sweet::Base::DB = undef;
    MyTest::CDBI::Sweet::Base->db_Main->disconnect;
  }

  # Delete test tables

  if($Inited_DB{'pg'})
  {
    # Postgres
    my $dbh = Rose::DB->new('pg')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test_code_names');
    $dbh->do('DROP TABLE rose_db_object_test_products');
    $dbh->do('DROP TABLE rose_db_object_test_categories');
    $dbh->do('DROP TABLE rose_db_object_test_codes');

    $dbh->disconnect;
  }

  if($Inited_DB{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test_code_names');
    $dbh->do('DROP TABLE rose_db_object_test_products');
    $dbh->do('DROP TABLE rose_db_object_test_categories');
    $dbh->do('DROP TABLE rose_db_object_test_codes');

    $dbh->disconnect;
  }

  if($Inited_DB{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test_code_names');
    $dbh->do('DROP TABLE rose_db_object_test_products');
    $dbh->do('DROP TABLE rose_db_object_test_categories');
    $dbh->do('DROP TABLE rose_db_object_test_codes');

    $dbh->disconnect;
  }
}
