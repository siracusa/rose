package Rose::DB::Object::ConventionManager::Null;

use strict;

use Rose::DB::Object::ConventionManager;
our @ISA = qw(Rose::DB::Object::ConventionManager);

our $VERSION = '0.01';

our $Instance;

# This class is a singleton
sub new
{
  my($class) = shift;
  return $Instance ||= $class->SUPER::new(@_);
}

sub parent { }
sub meta { }
sub class_to_table_singular { }
sub class_to_table_plural { }
sub table_to_class { }
sub auto_table_name { }
sub auto_primary_key_column_names { }
sub default_singular_to_plural { }
sub init_singular_to_plural_function { }
sub init_plural_to_singular_function { }
sub singular_to_plural { }
sub plural_to_singular { }
sub auto_foreign_key { }
sub auto_relationship { }
sub auto_relationship_one_to_one { }
sub auto_relationship_one_to_many { }
sub auto_relationship_many_to_many { }

1;
