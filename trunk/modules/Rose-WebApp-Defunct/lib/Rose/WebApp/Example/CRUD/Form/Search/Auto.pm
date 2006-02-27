package Rose::WebApp::Example::CRUD::Form::Search::Auto;

use strict;

use Carp;

use Rose::HTML::Form::Field::Text;
use Rose::HTML::Form::Field::Submit;
use Rose::HTML::Form::Field::DateTime;
use Rose::HTML::Form::Field::DateTime::Range;

use Rose::WebApp::Example::CRUD::Form::Search;
our @ISA = qw(Rose::WebApp::Example::CRUD::Form::Search);

use Rose::Object::MakeMethods::Generic
(
  scalar => 'sort_by_default',
  array  => 'sort_by_values',
  hash   => 'sort_by_labels',
);

our $Debug = 0;

sub search_columns
{
  my($self) = shift;

  if(@_)
  {
    $self->SUPER::search_columns(@_);
    $self->fields(undef);
    $self->build_form();
  }

  return $self->SUPER::search_columns(@_);
}

sub build_form
{
  my($self) = shift;

  my %fields;

  my $app = $self->app;

  $fields{'per_page'} =
    Rose::HTML::Form::Field::PopUpMenu->new(
      name    => 'per_page',
      label   => 'Per Page',
      options => [ 25, 50, 100 ],
      default => 25);

  $fields{'list_button'} = 
    Rose::HTML::Form::Field::Submit->new(
      name  => 'list', 
      value => 'List ' . _make_label($app->object_name_plural));

  my $object_class = $app->object_class 
    or croak "Missing object_class()";

  my $meta = $object_class->meta 
    or croak "No metadata found for $object_class";

  my @sort_by;

  # Default sort: primary key columns plus any single-column unique keys.
  push(@sort_by, $meta->primary_key_columns, 
                 map { $_->[0] } grep { @{$_} == 1 } $meta->unique_keys);

  foreach my $name ($self->search_columns)
  {
    my $col_meta = $meta->column($name)
      or croak "No field column named $name found in $self";

    my $type = $col_meta->type;

    if($type =~ /\bdate|timestamp/)
    {
      $fields{$name} = 
        Rose::HTML::Form::Field::DateTime::Range->new(
          name          => $name,
          output_format => '%Y-%m-%d %H:%M',
          label         => _make_label($name),
          size          => 16);
    }
    elsif($type =~ /^(?:int(eger)?|float|decimal)$/)
    {
      $fields{$name} = 
        Rose::HTML::Form::Field::Text->new(
          name      => $name,
          label     => _make_label($name),
          size      => 10,
          maxlength => 15);
    }
    else # if($type =~ /^(?:(?:var)?char(?:acter)?|text$/)
    {
      my $maxlen = $col_meta->can('length') ? $col_meta->length : 255;

      $fields{$name} = 
        Rose::HTML::Form::Field::Text->new(
          name      => $name,
          label     => _make_label($name),
          size      => 15,
          maxlength => $maxlen);
    }
  }

  # Integrate customized sort-by information, if any
  my $sort_by_values = $self->sort_by_values;

  if($sort_by_values && @$sort_by_values)
  {
    @sort_by = @$sort_by_values;
  }
  else
  {
    my %seen = map { $_ => 1 } @sort_by;
    push(@sort_by, map { /date|time|start|end|changed|last_modified$/i ? "$_ DESC" : $_ } 
                   grep { !$seen{$_}++ && /name|date|time|start|end|changed|last_modified$/i }
                   $meta->column_names);
  }

  my %sort_by = (map { ($_ => _make_label($_)) } @sort_by);

  if(my $sort_by_labels = $self->sort_by_labels)
  {
    @sort_by{keys %$sort_by_labels} = values(%$sort_by_labels);
  }

  unless($sort_by_values && @$sort_by_values)
  {
    @sort_by = sort { lc $sort_by{$a} cmp lc $sort_by{$b} } @sort_by;
  }

  $fields{'sort'} = 
    Rose::HTML::Form::Field::PopUpMenu->new(
      name    => 'sort',
      label   => 'Sort By',
      options => \@sort_by,
      labels  => \%sort_by,
      default => $self->sort_by_default);

  $self->add_fields(%fields);
}

sub _make_label
{
  my($str) = shift;

  for($str)
  {
    tr/_/ /;
    s/(\S+)/\u$1/g;
    s/ DESC$//;
  }

  return $str;
}
1;
