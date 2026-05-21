-- wordpress-vulnerable-lab — intentional SQL dump leak.
-- Filename: dump.sql (commonly forgotten on real prod servers).
--
-- MySQL dump 10.13  Distrib 5.7.31, for Linux (x86_64)
--
-- Host: localhost    Database: wordpress
-- ------------------------------------------------------

DROP TABLE IF EXISTS `wp_users`;
CREATE TABLE `wp_users` (
  `ID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_login` varchar(60) NOT NULL DEFAULT '',
  `user_pass` varchar(255) NOT NULL DEFAULT '',
  `user_email` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `wp_users` VALUES
  (1,'admin','$P$BlabFakeHashForAdminLabUseOnly.',                'admin@vuln.lab'),
  (2,'editor','$P$BlabFakeHashForEditorLabUseOnly.',              'editor@vuln.lab'),
  (3,'subscriber','$P$BlabFakeHashForSubscriberLabUseOnly.',      'sub@vuln.lab');

-- Dump completed on 2026-05-19 09:15:00
