# MySQL dump 7.1
#
# Host: localhost    Database: callerid
#--------------------------------------------------------
# Server version	3.22.32-log

#
# Table structure for table 'calls'
#
CREATE TABLE calls (
  name char(32) DEFAULT '' NOT NULL,
  number char(16) DEFAULT '' NOT NULL,
  local_datetime bigint(20) DEFAULT '0',
  keyval int(11) DEFAULT '0' NOT NULL auto_increment,
  PRIMARY KEY (keyval)
);

