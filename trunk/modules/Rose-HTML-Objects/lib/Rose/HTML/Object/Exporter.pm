package Rose::HTML::Object::Exporter;

use strict;

use Carp;

our $VERSION = 0.544_01;

our $Debug = 0;

use Rose::Class::MakeMethods::Set
(
  inheritable_set => 
  [
    '_export_tag' =>
    {
      list_method    => '_export_tags',
      clear_method   => 'clear_export_tags',
      add_method     => '_add_export_tag',
      delete_method  => 'delete_export_tag',
      deletes_method => 'delete_export_tags',
    },

    '_pre_import_hook',
    {
      clear_method   => 'clear_pre_import_hooks',
      add_method     => 'add_pre_import_hook',
      adds_method    => 'add_pre_import_hooks',
      delete_method  => 'delete_pre_import_hook',
      deletes_method => 'delete_pre_import_hooks',    
    },
  ],
);

our %Imported;

sub imported
{
  my($class, $symbol) = (shift, shift);

  if(@_)
  {
    return $Imported{$class}{$symbol}{'from'} = shift;
  }

  return $Imported{$class}{$symbol};
}

our $Target_Class;

sub import
{
  my($class) = shift;

  my $target_class = $Target_Class || (caller)[0];

  my($force, @symbols, %import_as, $imported);

  foreach my $arg (@_)
  {
    if($arg =~ /^-?-force$/)
    {
      $force = 1;
    }
    elsif($arg =~ /^:(.+)/)
    {
      my $symbols = $class->export_tag($1) or
        croak "Unknown export tag - '$arg'";

      push(@symbols, @$symbols);
    }
    elsif(ref $arg eq 'HASH')
    {
      while(my($symbol, $name) = each(%$arg))
      {
        push(@symbols, $symbol);
        $import_as{$symbol} = $name;
      }
    }
    else
    {
      push(@symbols, $arg);
    }
  }

  foreach my $symbol (@symbols)
  {
    my $code = $class->can($symbol) or 
      croak "Could not import symbol '$symbol' from $class - no such symbol";

    my $is_constant = (defined prototype($code) && !length(prototype($code))) ? 1 : 0;

    my $import_as = $import_as{$symbol} || $symbol;

    my $existing_code = $target_class->can($import_as);

    no strict 'refs';
    no warnings 'uninitialized';

    if($existing_code && !$force && (
         ($is_constant && $existing_code eq \&{"${target_class}::$import_as"}) ||
         (!$is_constant && $existing_code)))
    {
      next  if($Imported{$target_class}{$import_as});

      croak "Could not import symbol '$import_as' from $class into ",
            "$target_class - a symbol by that name already exists. ",
            "Pass a '--force' argument to import() to override ",
            "existing symbols."
    }

    if(my $hooks = $class->pre_import_hooks($symbol))
    {
      foreach my $code (@$hooks)
      {
        eval { $code->($class, $symbol, $target_class, $import_as) };

        if($@)
        {
          croak "Could not import symbol '$import_as' from $class into ",
                "$target_class - $@";
        }
      }
    }

    if($is_constant)
    {
      no strict 'refs';
      $Debug && warn "${target_class}::$import_as = ${class}::$symbol\n";
      *{$target_class . '::' . $import_as} = *{"${class}::$symbol"};
    }
    else
    {
      no strict 'refs';
      $Debug && warn "${target_class}::$import_as = ${class}->$symbol\n";
      *{$target_class . '::' . $import_as} = $code;
    }

    $Imported{$target_class}{$import_as}{'from'} = $class;
  }
}

sub export_tag
{
  my($class, $tag) = (shift, shift);

  if(index($tag, ':') == 0)
  {
    croak 'Tag name arguments to export_tag() should not begin with ":"';
  }

  if(@_ && !$class->_export_tag_value($tag))
  {
    $class->_add_export_tag($tag);
  }

  if(@_ && (@_ > 1 || (ref $_[0] || '') ne 'ARRAY'))
  {
    croak 'export_tag() expects either a single tag name argument, ',
          'or a tag name and a reference to an array of symbol names';
  }

  my $ret = $class->_export_tag_value($tag, @_);

  croak "No such tag: $tag"  unless($ret);

  return wantarray ? @$ret : $ret;
}

sub export_tags
{
  my($class) = shift;
  return $class->_export_tags  unless(@_);
  $class->clear_export_tags;
  $class->add_export_tags(@_);
}

sub add_export_tags
{
  my($class) = shift;

  while(@_)
  {
    my($tag, $arg) = (shift, shift);
    $class->export_tag($tag, $arg);
  }
}

sub add_to_export_tag
{
  my($class, $tag) = (shift, shift);
  my $list = $class->export_tag($tag);
  push(@$list, @_);
}

sub pre_import_hook
{
  my($class, $symbol) = (shift, shift);

  if(@_ && !$class->_pre_import_hook_value($symbol))
  {
    $class->add_pre_import_hook($symbol);
  }

  if(@_ && (@_ > 1 || (ref $_[0] && (ref $_[0] || '') !~ /\A(?:ARRAY|CODE)\z/)))
  {
    croak 'pre_import_hook() expects either a single symbol name argument, ',
          'or a symbol name and a code reference or a reference to an array ',
          'of code references';
  }

  if(@_)
  {
    unless(ref $_[0] eq 'ARRAY')
    {
      $_[0] = [ $_[0] ];
    }
  }

  my $ret = $class->_pre_import_hook_value($symbol, @_) || [];

  return wantarray ? @$ret : $ret;
}

sub pre_import_hooks { shift->pre_import_hook(shift) }

1;
