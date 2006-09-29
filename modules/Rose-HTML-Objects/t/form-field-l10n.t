#!/usr/bin/perl -w

use strict;

use Test::More tests => 40;

use FindBin qw($Bin);

use lib "$Bin/lib";

use Rose::HTML::Object::Errors qw(CUSTOM_ERROR FIELD_REQUIRED);
use Rose::HTML::Object::Messages qw(CUSTOM_MESSAGE FIELD_REQUIRED_GENERIC);

BEGIN
{
  use_ok('Rose::HTML::Form::Field');
  use_ok('MyField');
}

use MyObject::Messages qw(:all);

my $o = MyField->new;

$o->localize_label;
$o->localize_description;

is($o->label, 'Dog', 'localized label 1');
$o->locale('fr');
is($o->label, 'Chien', 'localized label 2');

MyField->localizer->add_localized_message_text( 
  name => 'FIELD_LABEL',
  text => 
  {
    en => 'Cat',
    fr => 'Chat',
  });

is($o->label, 'Chat', 'localized label 3');
$o->locale('en');
is($o->label, 'Cat', 'localized label 4');

$o->label('Cow');

is($o->label, 'Cow', 'unlocalized label 1');
$o->locale('fr');
is($o->label, 'Cow', 'unlocalized label 2');

is($o->description, undef, 'localized description 1');

my $id = MyField->localizer->add_localized_message( 
  name => 'EMAIL_FIELD_LABEL',
  text => 
  {
    en => 'Email',
    fr => 'Courriel',
  });

$o->label_message_id($id);

$o->locale('en');
is($o->label, 'Email', 'new localized label 1');
$o->locale('fr');
is($o->label, 'Courriel', 'new localized label 2');

$id = MyField->localizer->add_localized_message( 
  name => 'NAME_FIELD_LABEL',
  text => 
  {
    en => 'Name',
    fr => 'Nom',
  });

MyField->localizer->import_message_ids(':all');

$o->label_message_id(NAME_FIELD_LABEL());

$o->locale('en');
is($o->label, 'Name', 'new localized label 3');
$o->locale('fr');
is($o->label, 'Nom', 'new localized label 4');

$o->locale('en');

# has_error(s)
ok(!$o->has_error, 'has_error 1');
ok(!$o->has_errors, 'has_errors 1');

# errors
$o->errors('Error one', 'Error two');

ok($o->has_error, 'has_error 2');
ok($o->has_errors, 'has_errors 2');

my @errors = $o->errors;
is(scalar @errors, 2, 'errors 1');
is_deeply([ map { "$_" } @errors ], [ 'Error one', 'Error two' ], 'errors 2');
is_deeply([ map { $_->id } @errors ], [ CUSTOM_ERROR, CUSTOM_ERROR ], 'errors 3');
my $error = $o->error;
is($error->id, CUSTOM_ERROR, 'errors 4');

# error_id
is($o->error_id, CUSTOM_ERROR, 'error_id 1');
is_deeply([ $o->error_ids ], [ CUSTOM_ERROR, CUSTOM_ERROR ], 'error_ids 1');

# add_error
$o->add_error(FIELD_REQUIRED);
@errors = $o->errors;
is_deeply([ map { "$_" } @errors ], [ 'Error one', 'Error two', 'This is a required field.' ], 'add_error 1');
is_deeply([ map { $_->id } @errors ], [ CUSTOM_ERROR, CUSTOM_ERROR, FIELD_REQUIRED ], 'add_error 2');

# add_error_ids
$o->errors(FIELD_REQUIRED, 'Error two');
$o->add_error_ids(FIELD_REQUIRED, FIELD_REQUIRED);
@errors = $o->errors;
is_deeply([ map { "$_" } @errors ], [ 'This is a required field.', 'Error two', 
          'This is a required field.', 'This is a required field.' ], 'add_error_ids 1');
is_deeply([ map { $_->id } @errors ], [ FIELD_REQUIRED, CUSTOM_ERROR, FIELD_REQUIRED, FIELD_REQUIRED ], 'add_error_ids 2');

# add_error_id
$o->errors(FIELD_REQUIRED, 'Error two');
$o->add_error_id(FIELD_REQUIRED);
@errors = $o->errors;
is_deeply([ map { "$_" } @errors ], [ 'This is a required field.', 'Error two', 
          'This is a required field.', ], 'add_error_id 1');
is_deeply([ map { $_->id } @errors ], [ FIELD_REQUIRED, CUSTOM_ERROR, FIELD_REQUIRED, ], 'add_error_id 2');

ok($o->has_error, 'has_error 3');
ok($o->has_errors, 'has_errors 3');

$o->error('Foo');
@errors = $o->errors;
is(scalar @errors, 1, 'error 1');

ok($o->has_error, 'has_error 4');
ok($o->has_errors, 'has_errors 4');

$o->error(undef);
ok(!$o->has_error, 'has_error 5');
ok(!$o->has_errors, 'has_errors 5');

$o->errors('foo', 'bar');
$o->errors(undef);
ok(!$o->has_error, 'has_error 6');
ok(!$o->has_errors, 'has_errors 6');

$o->errors('foo');
$o->errors([]);
ok(!$o->has_error, 'has_error 7');
ok(!$o->has_errors, 'has_errors 7');