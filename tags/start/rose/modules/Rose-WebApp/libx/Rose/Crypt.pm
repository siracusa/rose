package Rose::Crypt;

use strict;

use Carp;

use MIME::Base64();
use Crypt::CBC;

use Rose::Crypt::Conf qw(%CONF);

# XXX: See comment in encrypt() below
#my $Current_Cipher;

my $CIPHER_TAG_SEP = ':';

my %TAG_TO_CIPHER =
(
  'XA' => 'Crypt::Blowfish',
  'XB' => 'Crypt::DES',
);

my %CIPHER_TO_TAG;
{
  foreach my $tag (keys %TAG_TO_CIPHER)
  {
    $CIPHER_TO_TAG{$TAG_TO_CIPHER{$tag}} = $tag;
  }
}

our %Crypt;

our $Debug = 0;

sub crypt_key { $CONF{'KEY'} }
sub cipher    { $CONF{'CIPHER'} }

sub _get_crypt
{
  my($class) = shift;

  if(@_)
  {
    unless($_[0] =~ /^([^$CIPHER_TAG_SEP]{2})$CIPHER_TAG_SEP/o)
    {
      carp "Item to decrypt does not begin with cipher tag";
      $Debug && warn hexdump($_[0]);
      return;
    }

    my($cipher_tag) = $1;

    unless(exists $TAG_TO_CIPHER{$cipher_tag})
    {
      warn "Unknown cipher tag: '$cipher_tag'";
      return;
    }

    my $cipher = $TAG_TO_CIPHER{$cipher_tag};

    # XXX: See comment in encrypt() below
    #$Current_Cipher = $cipher;

    return $Crypt{$cipher} ||= Crypt::CBC->new($class->crypt_key, $cipher);
  }

  # XXX: See comment in encrypt() below
  #$Current_Cipher = $class->cipher;

  return $Crypt{$class->cipher} ||=
    Crypt::CBC->new($class->crypt_key, $class->cipher);
}

sub encrypt
{
  my($class) = shift;
  my $crypt = $class->_get_crypt() || return;

  # WARNING: Dangerous reach-in to get at $crypt->{'crypt'}
  # Revert to (slightly less efficient) use of $Current_Cipher
  # if this goes awry in the future

  my $current = ref $crypt->{'crypt'};

  die "Unknown cipher: $current\n"
    unless(exists $CIPHER_TO_TAG{$current});

  return join($CIPHER_TAG_SEP,
              $CIPHER_TO_TAG{$current},
              $crypt->encrypt($_[0]));
}

sub encrypt_base64 { MIME::Base64::encode_base64(shift->encrypt(@_), '') }

sub decrypt
{
  my($class) = shift;
  my $crypt = $class->_get_crypt($_[0]) || return;
  return $crypt->decrypt(substr($_[0], 3));
}

sub decrypt_base64
{
  my($class) = shift;
  return $class->decrypt(MIME::Base64::decode_base64($_[0]));
}

sub hexdump
{
  # Allow to be called as class method for this package only
  shift  if($_[0] eq __PACKAGE__);

  my($data) = join('', @_);

  my($ret, $hex, $ascii, $len, $i);

  $len = length($data);

  for($i = 0; $i < $len; $i++)
  {
    if($i > 0)
    {
      if($i % 4 == 0)
      {
        $hex .= ' ';
      }

      if($i % 16 == 0)
      {
        $ret .= "$hex$ascii\n";
        $ascii = $hex = '';
      }
    }

    $hex .= sprintf("%02x ", ord(substr($data, $i, 1)));

    $ascii .= sprintf("%c", (ord(substr($data, $i, 1)) > 31 and
                             ord(substr($data, $i, 1)) < 127) ?
                             ord(substr($data, $i, 1)) : 46);
  }

  if(length($hex) < 50)
  {
    $hex .= ' ' x (50 - length($hex));
  }

  $ret .= "$hex  $ascii\n";

  return $ret;
}

1;
