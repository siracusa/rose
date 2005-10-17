package Rose::DB::Object::ConventionManager::Null;

use strict;

use Rose::DB::Object::ConventionManager;
our @ISA = qw(Rose::DB::Object::ConventionManager);

our $VERSION = '0.01';

sub class_to_table_singular { }
sub class_to_table_plural { }
sub table_to_class { }
sub auto_table_name  { }
sub auto_primary_key_column_names  { }
sub default_singular_to_plural  { }
sub singular_to_plural  { }
sub auto_foreign_key  { }
sub auto_relationship  { }
sub auto_relationship_one_to_one { }

1;
