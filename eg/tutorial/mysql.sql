-- Table set-up for the tutorial ordering system when running on MySQL

CREATE TABLE orders (
	`id`               INT AUTO_INCREMENT,
	`customer_name`    VARCHAR(255) NOT NULL,
	`customer_address` MEDIUMTEXT NOT NULL,
	PRIMARY KEY (`id`)
) TYPE=InnoDB;

CREATE TABLE order_items (
	`order`       INT NOT NULL,
	`product_id`  INT NOT NULL,
	`description` VARCHAR(255) NOT NULL,
	`quantity`    INT NOT NULL DEFAULT 1,
	PRIMARY KEY (`order`, `product_id`),
	FOREIGN KEY (`order`) REFERENCES orders(`id`)
) TYPE=InnoDB;
