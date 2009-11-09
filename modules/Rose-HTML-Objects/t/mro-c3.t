#!/usr/bin/perl -w

use strict;

use Cwd qw(abs_path);
use Test::More; 
use File::Find;
use FindBin qw($Bin);
use lib "$Bin/../lib";

eval "use mro 'c3'";

plan(skip_all => 'mro required for testing c3 class hierarchy')  if($@); 
plan(tests => 61);

my $dir = abs_path("$Bin/../lib");

find(sub 
{
  return  unless(/\.pm$/);
  my $path = $File::Find::name;
  my $package = $path;

  for($package)
  {
    s{^$dir/}{}o;
    s{\.pm$}{};
    s{/}{::}g;
  }

  eval "use $package;";
  die "Could not load $package: $@"  if($@);

  return unless ($package->isa('Rose::Object'));

  my $subclass = "My::$package";

  my $code=<<"EOF";
package $subclass;

use mro 'c3';

use base '$package';

sub init
{
  my(\$self) = shift;
  \$self->next::method(\@_);
}
EOF

  eval $code;
  die "Could not compile code:\n$code\n\n$@"  if($@);

  eval
  {
    if($subclass->can('name'))
    {
      $subclass->new(name => 'abc');
    }
    else
    {
      $subclass->new;
     }
  };
  die "Could not test $package: $@"  if($@);
  ok(!$@, $package);
},
$dir);
