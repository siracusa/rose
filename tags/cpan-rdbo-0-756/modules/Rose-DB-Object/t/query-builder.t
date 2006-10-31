#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::QueryBuilder');
  Rose::DB::Object::QueryBuilder->import(qw(build_select));
}

SKIP:
{
  skip("all tests", 1)  unless(have_db('sqlite'));

  my $dbh = get_dbh('sqlite');

  my $sql = 
    build_select
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
        id => [ \'id', 1 ],
      ],
      query_is_sql => 1
    );

  is($sql . "\n", <<"EOF", 'build_select() IN scalar ref');
SELECT 
COUNT(*)
FROM
  articles
WHERE
  id IN (id, '1') AND
  category IN ('sports', 'science') AND
  type = 'news' AND
  (title LIKE '%million%' OR title LIKE '%resident%')
EOF

  # XXX: Need more tests here...
}
