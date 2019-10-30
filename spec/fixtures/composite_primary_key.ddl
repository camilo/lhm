
CREATE TABLE `composite_primary_key` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `shop_id` bigint(20) NOT NULL,
  PRIMARY KEY (`shop_id`,`id`),
  INDEX `index_key_on_id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
