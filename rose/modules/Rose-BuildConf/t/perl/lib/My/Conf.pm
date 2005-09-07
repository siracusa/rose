package My::Conf;

use strict;

use Rose::Conf::FileBased;
our @ISA = qw(Rose::Conf::FileBased);

our %CONF =
(
  A => 1,
  B => 2,
  C => 3,

  'D:E' => 'four',

  F => 
  {
    'f1:1' => 'one one',
    'f2:2' => 'two two',
  },

  q{a 1@#$%&^*)_+::'\\" ()*,./'} => 'yikes',

  q{b 1@#$%&^*)_+::'\\" ()*,./'} => 
  {
    q{a 1@#$%&^*)_+::'\\" ()*,./'} => 'yikes2',
  },

  'I : H : S' => 'i h s',

  DEV  => 1,
  ROOT => 'foo/bar',
);

1;
