# Welcome to Rose

Rose is a set of Perl modules focused on web application development. The modules that make up Rose include a DBI abstraction layer, an object-relational mapper (ORM), and an HTML widget toolkit. See [the wiki](https://github.com/siracusa/rose/wiki) for more information.

Supported databases are: PostgreSQL, MySQL, Oracle, Informix, and SQLite.

IMPORTANT: Most of the tests in this module need to connect  to a database in order to run.  The tests need full privileges on this database. See the file "t\00-warning.t" for more details.

To see the default values used for connections, consult the file "\modules\Rose-DB\t\test-lib.pl". 

To run only the SQLite unit tests, use the following command in the parent directory of "t/" :
prove -v -l t\sqlite.t

