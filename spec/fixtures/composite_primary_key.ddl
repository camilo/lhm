
CREATE TABLE `composite_primary_key` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  PRIMARY KEY (`shop_id`,`id`),
  INDEX `index_composite_primay_key_on_id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
