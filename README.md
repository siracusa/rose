# Welcome to Rose

Rose is a set of Perl modules focused on web application development. The modules that make up Rose include a DBI abstraction layer, an object-relational mapper (ORM), and an HTML widget toolkit. See [the wiki](https://github.com/siracusa/rose/wiki) for more information.

WARNING: Most of the tests in this module need to connect  to a database in order to run.  The tests need full privileges on this database. See the file "t\00-warning.t" for more details.

To see the default values used for connections, consult the file "\modules\Rose-DB\t\test-lib.pl". 

To run only the SQLite tests, use the following command in the parent directory of "t/" :
prove -v -l t\sqlite.t


##
## By default, the tests will try to connect to the database named "test"
## running on "localhost" using the default superuser username for each
## database type and an empty password.
##
## If you have setup your database in a secure manner, these connection
## attempts will fail, and the tests will be skipped.  If you want to override
## these values, set the following environment variables before running tests.
## (The current values are shown in parentheses.)
##
## PostgreSQL:
##
##     RDBO_PG_DSN        (dbi:Pg:dbname=test;host=localhost)
##     RDBO_PG_USER       (postgres)
##     RDBO_PG_PASS       (<none>)
##
## MySQL:
##
##     RDBO_MYSQL_DSN     (dbi:mysql:database=test;host=localhost)
##     RDBO_MYSQL_USER    (root)
##     RDBO_MYSQL_PASS    (<none>)
##
## Oracle:
##
##     RDBO_ORACLE_DSN    (dbi:Oracle:dbname=test)
##     RDBO_ORACLE_USER   (<none>)
##     RDBO_ORACLE_PASS   (<none>)
##
## Informix:
##
##     RDBO_INFORMIX_DSN  (dbi:Informix:test@test)
##     RDBO_INFORMIX_USER (<none>)
##     RDBO_INFORMIX_PASS (<none>)
##
## SQLite: To disable the SQLite tests, set this environment varible
##
##     RDBO_NO_SQLITE (<undef>)