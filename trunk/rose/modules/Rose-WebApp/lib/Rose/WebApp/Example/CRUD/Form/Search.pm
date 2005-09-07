package Rose::WebApp::Example::CRUD::Form::Search;

use strict;

use Carp;

use Rose::HTML::Form;
use Rose::WebApp::Child;
our @ISA = qw(Rose::HTML::Form Rose::WebApp::Child);

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  array  => 'search_columns',
);

sub method { 'get' }

our %Numeric_Comparisons =
(
  '<'  => 'lt',
  '<=' => 'le',
  '>=' => 'ge',
  '>'  => 'gt',
  '<>' => 'ne',
  '!=' => 'ne',
  '='  => 'eq',
);

sub manager_args_from_form
{
  my($self) = shift;

  my(%args, @query);

  my $obj_class = $self->app->object_class 
    or croak "No defined object_class() for ", $self->app;

  $args{'obj_class'} = $obj_class;

  foreach my $name ($self->search_columns)
  {
    my $field = $self->field($name) 
      or croak "No field named $name found in form $self";
print STDERR "$name = $field\n";
    next  if($field->is_empty);
print STDERR "$name NOT EMPTY\n";
    my $value = $field->internal_value;
print STDERR "$name = $value\n";
#print STDERR "META = $obj_class->meta->column($name) = ", ref($obj_class->meta->column($name)), "\n";
    if($field->isa('Rose::HTML::Form::Field::Date::Range'))
    {
      my $col_name = $field->name;

      my($min, $max) = @$value;
print STDERR "MIN = $min, MAX = $max, COL = $col_name\n";      
      push(@query, $col_name => { ge => $min },
                   $col_name => { le => $max });
    }
    elsif(my $col_meta = $obj_class->meta->column($name))
    {
#print STDERR "COL META = $obj_class->meta->column($name) = ", ref($col_meta), "\n";
      if($col_meta->isa('Rose::DB::Object::Metadata::Column::Character'))
      {
        my @vals;

        foreach my $str (ref $value eq 'ARRAY' ? @$value : ($value))
        {
          if($str =~ /[%*]/)
          {
            $str =~ tr/*/%/;
            push(@vals, { like => $str });
          }
          else
          {
            push(@vals, $str);
          }
        }

        push(@query, $name => (@vals == 1 ? $vals[0] : \@vals));
      }
      elsif($col_meta->isa('Rose::DB::Object::Metadata::Column::Numeric') ||
            $col_meta->isa('Rose::DB::Object::Metadata::Column::Integer') ||
            ref $col_meta eq 'Rose::DB::Object::Metadata::Column::Scalar')
      {
        my @vals;
#print STDERR "NUM\n";
        foreach my $val (ref $value eq 'ARRAY' ? @$value : ($value))
        {
          if($val =~ s/^([><]=?|\!?=|<>) *//)
          {
#print STDERR "1 = $1\n";
            my $op = $Numeric_Comparisons{$1} || $1;
#print STDERR "OP = $op\n";
            push(@vals, { $op => $val });
          }
          else
          {
            push(@vals, $val);
          }
        }

        push(@query, $name => (@vals == 1 ? $vals[0] : \@vals));
      }
    }
    elsif($name =~ /^sort(?:_by)?$/)
    {
      $args{'sort_by'} = $value;
    }
  }

  $args{'query'} = \@query;

  return wantarray ? %args : \%args;
}

1;
