#!/usr/bin/perl -w

use strict;

use Test::More;

eval { require Test::Memory::Cycle };

plan(skip_all => 'Test::Memory::Cycle required leak tests')  if($@); 

package LeakForm;

use Rose::HTML::Form;
use base qw(Rose::HTML::Form);

sub build_form
{
  shift->add_fields
  (
    myfield => 
#    { type => 'text' },
    { 
      type    => 'selectbox', 
      options => [ 'm' => { label => 'aLabel' } ],
    },
  );
}

# use Rose::HTML::Form::Field::SelectBox;
# 
# FOO:
# {
#   my $foo = Rose::HTML::Form::Field::SelectBox->new(options =>  [ 'm' => { label => 'aLabel' } ]);
# }
# __END__
package main;

my $form = LeakForm->new;

Test::More->import(tests => 1);

Test::Memory::Cycle::memory_cycle_ok($form);

my $first_size = `/bin/ps -orss= -p $$`;
my $last_size = 0;

#use Rose::HTML::Form::Field::SelectBox;
# use Devel::Leak;
# my $handle;
# my $count = Devel::Leak::NoteSV($handle);
# FOO:
# {
#   my $foo = Rose::HTML::Form::Field::SelectBox->new(options =>  [ 'm' => { label => 'aLabel' } ]);
# }
# Devel::Leak::CheckSV($handle);

use Rose::HTML::Form::Field::SelectBox;

use constant ITERATIONS => 1_000;
for(0 .. ITERATIONS) 
#if(0)
{
  #my $foo = Rose::HTML::Form::Field::SelectBox->new(options =>  [ 'm' => { label => 'aLabel' } ]);
  my $form = LeakForm->new();
next;
  my $size = `/bin/ps -orss= -p $$`;

  if($size > $last_size)
  {
    print "$size (+" . ($size - $last_size) . ")\n";
    $last_size = $size;
  }
}

$last_size ||= `/bin/ps -orss= -p $$`;
print "TOTAL: ", $last_size - $first_size, ' (', ((($last_size - $first_size) / ITERATIONS) * 1024), ")\n";