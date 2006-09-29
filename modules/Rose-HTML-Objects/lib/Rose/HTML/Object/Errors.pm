package Rose::HTML::Object::Errors;

use strict;

use Carp;

use base 'Rose::HTML::Object::Messages';

our $VERSION = '0.531';

BEGIN
{
  __PACKAGE__->message_names_list([]);
  __PACKAGE__->message_id_to_name_map({});
  __PACKAGE__->message_name_to_id_map({});
}

BEGIN
{
  *error_id_exists   = \&Rose::HTML::Object::Messages::message_id_exists;
  *error_name_exists = \&Rose::HTML::Object::Messages::error_name_exists;
  
  *get_error_id   = \&Rose::HTML::Object::Messages::get_message_id;
  *get_error_name = \&Rose::HTML::Object::Messages::get_message_name;
  
  *add_error    = \&Rose::HTML::Object::Messages::add_message;
  *add_errors   = \&Rose::HTML::Object::Messages::add_messages;
  *get_error_id = \&Rose::HTML::Object::Messages::get_message_id;
  
  *add_error  = \&Rose::HTML::Object::Messages::add_message;
  *add_errors = \&Rose::HTML::Object::Messages::add_messages;
}

#
# Errors
#

use constant CUSTOM_ERROR => -1;

# Field errors
use constant FIELD_REQUIRED      => 3;
use constant FIELD_PARTIAL_VALUE => 7;

# Form errors
use constant FORM_HAS_ERRORS => 100;

# Numerical errors
use constant NUM_INVALID_INTEGER          => 1300;
use constant NUM_INVALID_INTEGER_POSITIVE => 1301;
use constant NUM_NOT_POSITIVE_INTEGER     => 1302;
use constant NUM_BELOW_MIN                => 1303;
use constant NUM_ABOVE_MAX                => 1304;

# Date errors
use constant DATE_MIN_GREATER_THAN_MAX => 1500;

# Email errors
use constant EMAIL_INVALID => 1600;

# Phone errors
use constant PHONE_INVALID => 1650;

# Set errors
use constant SET_INVALID_QUOTED_STRING => 1700;
use constant SET_PARSE_ERROR           => 1701;

BEGIN { __PACKAGE__->add_errors }

1;
