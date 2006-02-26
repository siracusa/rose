package Rose::HTML::Form::Field::Group;

use strict;

use Carp();

use Rose::HTML::Util();

use Rose::HTML::Form::Field;
our @ISA = qw(Rose::HTML::Form::Field);

our $VERSION = '0.012';

our $Debug = undef;

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(rows columns) ],

  'scalar --get_set_init' => 
  [
    qw(html_linebreak xhtml_linebreak) 
  ],

  boolean => [ 'linebreak' => { default => 1 } ],
);

sub init
{
  my($self) = shift;

  $self->{'items'}    = [];
  $self->{'values'}   = {};
  $self->{'labels'}   = {};
  $self->{'defaults'} = {};

  $self->SUPER::init(@_);
}

use constant HTML_LINEBREAK  => "<br>\n";
use constant XHTML_LINEBREAK => "<br />\n";

sub init_html_linebreak  { HTML_LINEBREAK  }
sub init_xhtml_linebreak { XHTML_LINEBREAK }

sub _item_class       { '' }
sub _item_group_class { '' }
sub _item_name        { 'item' }
sub _item_name_plural { 'items' }

sub items
{
  my($self) = shift;

  if(@_)
  {
    $self->{'items'} = $self->_args_to_items(@_);
    $self->init_items;
  }

  return (wantarray) ? @{$self->{'items'}} : $self->{'items'};
}

*fields = \&items;

sub _html_item { $_[1]->html_field }

sub _args_to_items
{
  my($self) = shift;

  my(%labels, @choices, $items);

  my $class = $self->_item_class;
  my $group_class = $self->_item_group_class;

  if(@_ == 1 && ref $_[0] eq 'HASH')
  {
    %labels = %{$_[0]};
    @choices = sort keys %labels;
  }
  elsif(@_ == 1 && ref $_[0] eq 'ARRAY')
  {
    if(ref $_[0][0] && ($_[0][0]->isa($class) || $_[0][0]->isa($group_class)))
    {
      $items = $_[0];
    }
    else
    {
      @choices = @{$_[0]};
      %labels = map { $_ => $_  } @choices;
    }
  }
  elsif($_[0]->isa($class) || $_[0]->isa($group_class))
  {
    $items = [ @_ ];
  }
  else
  {
    Carp::croak "Odd number of " . $self->_item_name_plural . " found in hash argument"
      unless(@_ % 2 == 0);

    for(my $i = 0; $i < $#_; $i += 2)
    {
      push(@choices, $_[$i]);
    }

    %labels = @_;
  }

  if(keys %labels)
  {
    my @items;

    my $class = $self->_item_class;

    foreach my $value (@choices)
    {
      push(@$items, $class->new(value => $value, 
                                label => $labels{$value}));
    }
  }

  return (wantarray) ? @$items : $items;
}

sub add_items
{
  my($self) = shift;

  push(@{$self->{'items'}},  $self->_args_to_items(@_));

  $self->init_items;
}

*add_item = \&add_items;

sub label_items
{
  my($self) = shift;

  my $labels = $self->{'labels'};

  foreach my $item ($self->items)
  {
    if(exists $labels->{$item->html_attr('value')})
    {
      $item->label($labels->{$item->html_attr('value')});
    }
  }
}

sub clear
{
  my($self) = shift;

  $self->{'values'} = undef;

  foreach my $item ($self->items)
  {
    $item->clear;
  }

  $self->is_cleared(1);

  $self->init_items;
}

sub reset
{
  my($self) = shift;

  $self->input_value(undef);

  foreach my $item ($self->items)
  {
    $item->reset;
  }

  $self->is_cleared(0);

  $self->init_items;
}

sub labels
{
  my($self) = shift;

  if(@_)
  {
    my %labels;

    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'labels'} = $_[0];
    }
    else
    {
      Carp::croak "Odd number of items found in labels() hash argument"
        unless(@_ % 2 == 0);

      $self->{'labels'} = { @_ };
    }

    $self->label_items;
  }

  my $want = wantarray;

  return  unless(defined $want);

  my $group_class = $self->_item_group_class;

  my %labels;

  # Dumb linear search for now
  foreach my $item ($self->items)
  {
    if($item->isa($group_class))
    {
      foreach my $subitem ($item->items)
      {
        $labels{$subitem->html_attr('value')} = $subitem->label;
      }
    }
    else
    {
      $labels{$item->html_attr('value')} = $item->label;
    }
  }

  return $want ? %labels : \%labels;
}

sub html_field
{
  my($self) = shift;
  my $sep = ($self->linebreak) ? $self->html_linebreak : ' ';
  return join($sep, map { $_->html_field } $self->items);
}

*html_fields = \&html_field;

sub xhtml_field
{
  my($self) = shift;
  my $sep = ($self->linebreak) ? $self->xhtml_linebreak : ' ';
  return join($sep, map { $_->xhtml_field } $self->items);
}

*xhtml_fields = \&xhtml_field;

sub hidden_fields
{
  my($self) = shift;

  my @hidden;

  foreach my $item ($self->items)
  {
    push(@hidden, $item->hidden_field)  if($item->internal_value);
  }

  return (wantarray) ? @hidden : \@hidden;
}

sub escape_html
{
  my($self) = shift;

  return $self->{'escape_html'}  unless(@_);

  foreach my $field ($self->fields)
  {
    $field->escape_html(@_);
  }

  return $self->{'escape_html'} = shift;
}

# XXX: Could someday use Rose::HTML::Table::*

sub html_table
{
  my($self, %args) = @_;

  my $items = $args{'items'};

  return  unless(ref $items && @$items);

  my $format_item = $args{'format_item'} || 'html';

  my $total = @$items;
  my $rows  = $args{'rows'}    || $self->rows    || 1;
  my $cols  = $args{'columns'} || $self->columns || 1;

  my $per_cell = $total / ($rows * $cols);

  if($total % ($rows * $cols))
  {
    $per_cell = int($per_cell + 1);
  }

  my @table;

  my $i = 0;

  for(my $x = 0; $x < $cols; $x++)
  {
    for(my $y = 0; $y < $rows; $y++)
    {
      my $end = $i + $per_cell - 1;
      $end = $#$items  if($end > $#$items);
      $table[$y][$x] = [ @$items[$i .. $end] ];
      $i += $per_cell;
    }
  }

  my $sep = ($self->linebreak) ? $self->html_linebreak : ' ';

  my $html = '<table' . Rose::HTML::Util::html_attrs_string($args{'table'}) . ">\n";

  my @tr_attrs = (ref $args{'tr'} eq 'ARRAY') ? @{$args{'tr'}} : ($args{'tr'});
  my @td_attrs = (ref $args{'td'} eq 'ARRAY') ? @{$args{'td'}} : ($args{'td'});

  my $tr = 0;

  foreach my $col (@table)
  {
    my $tr_attrs = $tr_attrs[$tr] || $tr_attrs[-1];

    $html .= '<tr' . Rose::HTML::Util::html_attrs_string($tr_attrs) . ">\n";

    my $td = 0;

    foreach my $row (@$col)
    {
      my $td_attrs = $td_attrs[$td] || $td_attrs[-1];

      $html .= '<td' . Rose::HTML::Util::html_attrs_string($td_attrs) . '>' .
               join($sep, map { $self->$format_item($_) } @$row) .
               "</td>\n";

      $td++;
    }

    $html .= "</tr>\n";
    $tr++;
  }

  $html .= "</table>\n";

  return $html;
}

*xhtml_table = \&html_table;

1;
