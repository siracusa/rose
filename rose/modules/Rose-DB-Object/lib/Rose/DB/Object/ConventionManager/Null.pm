package Rose::DB::Object::ConventionManager::Null;

use strict;

use Rose::DB::Object::ConventionManager;
our @ISA = qw(Rose::DB::Object::ConventionManager);

our $VERSION = '0.01';

sub auto_table_name { }
sub auto_primary_key_column_names { }

1;
