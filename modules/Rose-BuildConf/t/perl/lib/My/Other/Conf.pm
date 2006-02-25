package My::Other::Conf;

use strict;

use Rose::Conf::FileBased;
our @ISA = qw(Rose::Conf::FileBased);

our %CONF =
(
  A => 'other1',
  B => 'other2',
  C => 'other3',

  'D:E' => 'other four',

  F => 
  {
    'f1:1' => 'Other one one',
    'f2:2' => 'Other two two',
  },

  q{a 1@#$%&^*)_+::'\\" ()*,./'} => 'other yikes',

  q{b 1@#$%&^*)_+::'\\" ()*,./'} => 
  {
    q{a 1@#$%&^*)_+::'\\" ()*,./'} => 'other yikes2',
  },

  'I : H : S' => 'other i h s',

  OTHER => 'here',
  DSN   => undef,
);

1;
