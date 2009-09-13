#!/usr/bin/perl -w

use strict;

use Test::More tests => 24;

use Rose::DB::Object;

BEGIN { require 't/test-lib.pl' }

our %Have;

our $Debug = 0;

foreach my $db_type (qw(mysql))
{
  SKIP:
  {
    skip("$db_type tests", 24)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  my $accounts = Rose::DB::Object::Manager->get_objects
  (
    debug         => $Debug,
    object_class  => 'My::Account',
    with_objects  => [ 'channels.itemMaps' ],
    #sort_by       => 't1.accountId ASC',
    multi_many_ok => 1,
   );
  
  test_accounts($accounts);
  
  $accounts = Rose::DB::Object::Manager->get_objects
  (
    debug         => $Debug,
    object_class  => 'My::Account',
    with_objects  => [ 'items.feature', 'channels.itemMaps' ],
    #sort_by       => 't1.accountId, t2.accountId, t3.featureId, t4.accountId, t5.channelId',
    multi_many_ok => 1,
  );

  test_accounts($accounts);

}

COUNTER:
{
  my $i;

  sub test_accounts 
  {
    my($accounts) = shift;
  
    foreach my $account (@$accounts) 
    {
      $Debug && print 'Account ID ', $account->accountId. " has the following channels:\n";
  
      foreach my $channel ($account->channels) 
      {
        $Debug && print '  Channel ID ', $channel->channelId, " has the following items:\n";
  
        foreach my $itemMap ($channel->itemMaps) 
        {
          if($Debug)
          {
            print '    Item ID ', $itemMap->itemId, ' is at position ', $itemMap->position;
            print "  <-- incorrect because map's channelId = ", $itemMap->channelId
              if($channel->channelId != $itemMap->channelId);
            print "\n";
          }

          $i ||= 0;
          is($channel->channelId, $itemMap->channelId, "id match $i");
          $i++;
        }
      }
    }
  }
}


BEGIN
{
  our %Have;

  #
  # MySQL
  #

  my $dbh;

  eval
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh or die Rose::DB->error;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE channel_item_map CASCADE');
      $dbh->do('DROP TABLE accounts CASCADE');
      $dbh->do('DROP TABLE channels CASCADE');
      $dbh->do('DROP TABLE features CASCADE');
      $dbh->do('DROP TABLE items CASCADE');
    }
  };

  if(!$@ && $dbh)
  {
    $Have{'mysql'} = 1;

    Rose::DB->default_type('mysql');

    $dbh->do(<<"EOF");
CREATE TABLE accounts
(
  accountId INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  owner     VARCHAR(100) NOT NULL
)
EOF

    $dbh->do($_) for(split(/;\n/, <<"EOF"));
INSERT INTO accounts (accountId, owner) VALUES (1, 'Account Owner 1');
INSERT INTO accounts (accountId, owner) VALUES (2, 'Account Owner 2');
EOF

    $dbh->do(<<"EOF");
CREATE TABLE channels
(
  channelId  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  accountId  INT UNSIGNED NOT NULL,
  name       VARCHAR(100) NOT NULL,

  KEY accountId (accountId)
)
EOF

    $dbh->do($_) for(split(/;\n/, <<"EOF"));
INSERT INTO channels (channelId, accountId, name) VALUES (1, 1, 'Channel 1 Name');
INSERT INTO channels (channelId, accountId, name) VALUES (2, 1, 'Channel 2 Name');
INSERT INTO channels (channelId, accountId, name) VALUES (3, 1, 'Channel 3 Name');
INSERT INTO channels (channelId, accountId, name) VALUES (4, 2, 'Channel 4 Name');
EOF

    $dbh->do(<<"EOF");
CREATE TABLE features
(
  featureId    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  accountId    INT UNSIGNED NOT NULL,
  description  VARCHAR(500) NOT NULL,

  KEY accountId (accountId)
)
EOF

    $dbh->do($_) for(split(/;\n/, <<"EOF"));
INSERT INTO features (featureId, accountId, description) VALUES (1, 1, 'Feature 1 description.');
INSERT INTO features (featureId, accountId, description) VALUES (2, 1, 'Feature 2 description.');
INSERT INTO features (featureId, accountId, description) VALUES (3, 1, 'Feature 3 description.');
EOF

    $dbh->do(<<"EOF");
CREATE TABLE items
(
  itemId     INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  accountId  INT UNSIGNED NOT NULL,
  featureId  INT UNSIGNED NULL,
  title       VARCHAR(100) NOT NULL,

  KEY accountId (accountId),
  KEY featureId (featureId)
)
EOF

    $dbh->do($_) for(split(/;\n/, <<"EOF"));
INSERT INTO items (itemId, accountId, featureId, title) VALUES (1, 1, 1, 'Item 1 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (2, 1, 1, 'Item 2 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (3, 1, 2, 'Item 3 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (4, 1, 2, 'Item 4 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (5, 1, 2, 'Item 5 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (6, 1, 2, 'Item 6 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (7, 1, 3, 'Item 7 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (8, 1, 3, 'Item 8 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (9, 1, 3, 'Item 9 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (10, 1, 3, 'Item 10 Title');
INSERT INTO items (itemId, accountId, featureId, title) VALUES (11, 1, 3, 'Item 11 Title');
INSERT INTO items (itemId, accountId, title) VALUES (12, 2, 'Item 12 Title');
EOF

    $dbh->do(<<"EOF");
CREATE TABLE channel_item_map
(
  channelId  INT UNSIGNED NOT NULL,
  itemId     INT UNSIGNED NOT NULL,
  position   INT UNSIGNED NOT NULL,

  PRIMARY KEY  (channelId, position),
  KEY channelId (channelId),
  KEY itemId (itemId)
)
EOF

    $dbh->do($_) for(split(/;\n/, <<"EOF"));
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (1, 1, 1);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (1, 2, 2);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (1, 3, 3);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (1, 4, 4);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (1, 5, 5);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (2, 6, 1);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (2, 7, 2);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (3, 8, 1);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (3, 9, 2);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (3, 10, 3);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (3, 11, 4);
INSERT INTO channel_item_map (channelId, itemId, position) VALUES (4, 12, 1);
EOF

    $dbh->do($_) for(grep { /\S/ } split(/;/, <<"EOF"));
ALTER TABLE channels ADD CONSTRAINT channels_to_accounts_fk
  FOREIGN KEY (accountId) REFERENCES accounts (accountId) ON DELETE CASCADE;

ALTER TABLE features ADD CONSTRAINT features_to_accounts_fk
  FOREIGN KEY (accountId) REFERENCES accounts (accountId) ON DELETE CASCADE;

ALTER TABLE channel_item_map 
  ADD CONSTRAINT channel_item_map_to_channels_fk
    FOREIGN KEY (channelId) REFERENCES channels (channelId) ON DELETE CASCADE,
  ADD CONSTRAINT channel_item_map_to_items_fk 
    FOREIGN KEY (itemId) REFERENCES items (itemId) ON DELETE CASCADE;

ALTER TABLE items 
  ADD CONSTRAINT items_to_accounts_fk 
    FOREIGN KEY (accountId) REFERENCES accounts (accountId) ON DELETE CASCADE,
  ADD CONSTRAINT items_to_features_fk
    FOREIGN KEY (featureId) REFERENCES features (featureId) ON DELETE CASCADE;
EOF

    $dbh->disconnect;

    package My::DB::Object;
    
    our @ISA = qw(Rose::DB::Object);
    
    sub init_db { Rose::DB->new }
    
    package My::Account;
    
    our @ISA = qw(My::DB::Object);
    
    __PACKAGE__->meta->setup
    (
      table => 'accounts',
    
      columns => 
      [
        accountId => 
        {
          type     => 'serial',
          not_null => 1,
        },
        owner => 
        {
          type     => 'varchar',
          length   => 100,
          not_null => 1,
        },
      ],
    
      primary_key_columns => ['accountId'],
    
      relationships => 
      [
        items => 
        {
          type       => 'one to many',
          class      => 'My::Item',
          column_map => { accountId => 'accountId' }
        },
        features => 
        {
          type       => 'one to many',
          class      => 'My::Feature',
          column_map => { featureId => 'featureId' }
        },
        channels => 
        {
          type       => 'one to many',
          class      => 'My::Channel',
          column_map => { accountId => 'accountId' }
        },
      ],
    );
    
    package My::ChannelItemMap;
    
    our @ISA = qw(My::DB::Object);
    
    __PACKAGE__->meta->setup
    (
      table => 'channel_item_map',
    
      columns => 
      [
        channelId => 
        {
          type     => 'integer',
          not_null => 1,
        },
        itemId => 
        {
          type     => 'integer',
          not_null => 1,
        },
        position => 
        {
          type     => 'integer',
          not_null => 1,
        },
      ],
    
      primary_key_columns => [ 'channelId', 'position' ],
    
      foreign_keys => 
      [
        channel => 
        {
          class       => 'My::Channel',
          key_columns => { channelId => 'channelId' },
        },
        item => 
        {
          class       => 'My::Item',
          key_columns => { itemId => 'itemId' },
        },
      ],
    );
    
    package My::Channel;
    
    our @ISA = qw(My::DB::Object);
    
    __PACKAGE__->meta->setup
    (
      table => 'channels',
    
      columns => 
      [
        channelId => 
        {
          type     => 'serial',
          not_null => 1,
        },
        accountId => 
        {
          type     => 'integer',
          not_null => 1,
        },
        name => 
        {
          type     => 'varchar',
          length   => 100,
          not_null => 1,
        },
      ],
    
      primary_key_columns => ['channelId'],
    
      foreign_keys => 
      [
        account => 
        {
          class       => 'My::Account',
          key_columns => { accountId => 'accountId' },
        },
      ],
    
      relationships => 
      [
        itemMaps => 
        {
          type       => 'one to many',
          class      => 'My::ChannelItemMap',
          column_map => { channelId => 'channelId' },
        },
      ],
    );
    
    package My::Feature;
    
    our @ISA = qw(My::DB::Object);
    
    __PACKAGE__->meta->setup
    (
      table => 'features',
    
      columns => 
      [
        featureId => 
        {
          type     => 'serial',
          not_null => 1,
        },
        accountId => 
        {
          type     => 'integer',
          not_null => 1,
        },
        description => 
        {
          type     => 'varchar',
          length   => 500,
          not_null => 1,
        },
      ],
    
      primary_key_columns => ['featureId'],
    
      foreign_keys => 
      [
        account => 
        {
          class       => 'My::Account',
          key_columns => { accountId => 'accountId' },
        },
      ],
    
      relationships => 
      [
        items => 
        {
          type       => 'one to many',
          class      => 'My::Item',
          column_map => { featureId => 'featureId' },
        },
      ],
    );
    
    package My::Item;
    
    our @ISA = qw(My::DB::Object);
    
    __PACKAGE__->meta->setup
    (
      table => 'items',
    
      columns => 
      [
        itemId => 
        {
          type     => 'serial',
          not_null => 1,
        },
        accountId => 
        {
          type     => 'integer',
          not_null => 1,
        },
        featureId => { type => 'integer', },
        title     => 
        {
          type     => 'varchar',
          length   => 100,
          not_null => 1,
        },
      ],
    
      primary_key_columns => ['itemId'],
    
      foreign_keys => 
      [
        account => 
        {
          class       => 'My::Account',
          key_columns => { accountId => 'accountId' },
        },
        feature => 
        {
          class       => 'My::Feature',
          key_columns => { featureId => 'featureId' },
        },
      ],
    
      relationships => 
      [
        channelMaps => 
        {
          type       => 'one to many',
          class      => 'My::ChannelItemMap',
          column_map => { itemId => 'itemId' },
        },
      ],
    );
  }
}

END
{
  # Delete test tables

  if($Have{'mysql'})
  {
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE channel_item_map CASCADE');
    $dbh->do('DROP TABLE accounts CASCADE');
    $dbh->do('DROP TABLE channels CASCADE');
    $dbh->do('DROP TABLE features CASCADE');
    $dbh->do('DROP TABLE items CASCADE');
    
    $dbh->disconnect;
  }
}
