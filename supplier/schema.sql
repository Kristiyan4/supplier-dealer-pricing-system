-- =============================================================
-- КУРСОВ ПРОЕКТ ПО БАЗИ ОТ ДАННИ
-- Тема: система за поддържане на доставчици, стоки, цени и дилъри
-- СУБД: MySQL 8.x / Engine: InnoDB
-- =============================================================

DROP DATABASE IF EXISTS supplier_dealer_system;
CREATE DATABASE supplier_dealer_system
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE supplier_dealer_system;

-- =============================================================
-- 1. CREATE TABLE заявки
-- =============================================================

CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(120) NOT NULL,
    bulstat VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(120),
    phone VARCHAR(30),
    address VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL,
    CONSTRAINT fk_categories_parent
      FOREIGN KEY (parent_id) REFERENCES categories(category_id)
      ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    category_id INT NULL,
    sku VARCHAR(40) NOT NULL UNIQUE,
    product_name VARCHAR(160) NOT NULL,
    description TEXT,
    unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
    stock_qty INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_products_stock CHECK (stock_qty >= 0),
    CONSTRAINT fk_products_supplier
      FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_products_category
      FOREIGN KEY (category_id) REFERENCES categories(category_id)
      ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

CREATE TABLE dealer_clients (
    dealer_id INT AUTO_INCREMENT PRIMARY KEY,
    dealer_name VARCHAR(140) NOT NULL,
    bulstat VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(120),
    phone VARCHAR(30),
    address VARCHAR(255),
    discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_dealer_discount CHECK (discount_percent BETWEEN 0 AND 100)
) ENGINE = InnoDB;

-- Времева таблица за цените: пази период на валидност на всяка цена.
-- Генерираната колона current_product_id позволява само една активна цена
-- за продукт, защото UNIQUE допуска множество NULL, но не и два еднакви id.
CREATE TABLE product_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'BGN',
    valid_from DATETIME NOT NULL,
    valid_to DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    current_product_id INT GENERATED ALWAYS AS
      (CASE WHEN valid_to IS NULL THEN product_id ELSE NULL END) STORED,
    CONSTRAINT chk_product_prices_price CHECK (price > 0),
    CONSTRAINT chk_product_prices_period CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT fk_prices_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE RESTRICT ON DELETE RESTRICT,
    UNIQUE KEY uq_product_price_from (product_id, valid_from),
    UNIQUE KEY uq_one_current_price_per_product (current_product_id)
) ENGINE = InnoDB;

CREATE TABLE product_views (
    view_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dealer_id INT NOT NULL,
    product_id INT NOT NULL,
    viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    CONSTRAINT fk_views_dealer
      FOREIGN KEY (dealer_id) REFERENCES dealer_clients(dealer_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_views_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE orders (
    order_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dealer_id INT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('NEW','CONFIRMED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'NEW',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_orders_total CHECK (total_amount >= 0),
    CONSTRAINT fk_orders_dealer
      FOREIGN KEY (dealer_id) REFERENCES dealer_clients(dealer_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE order_items (
    order_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NULL,
    line_total DECIMAL(12,2) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_order_items_price CHECK (unit_price IS NULL OR unit_price > 0),
    CONSTRAINT chk_order_items_total CHECK (line_total IS NULL OR line_total >= 0),
    CONSTRAINT fk_order_items_order
      FOREIGN KEY (order_id) REFERENCES orders(order_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    UNIQUE KEY uq_order_product (order_id, product_id)
) ENGINE = InnoDB;

CREATE TABLE product_ratings (
    rating_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dealer_id INT NOT NULL,
    product_id INT NOT NULL,
    order_item_id BIGINT NULL,
    rating TINYINT NOT NULL,
    comment VARCHAR(500),
    rated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_product_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT fk_ratings_dealer
      FOREIGN KEY (dealer_id) REFERENCES dealer_clients(dealer_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ratings_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ratings_order_item
      FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    UNIQUE KEY uq_dealer_product_rating (dealer_id, product_id)
) ENGINE = InnoDB;

CREATE TABLE product_rating_stats (
    product_id INT PRIMARY KEY,
    avg_rating DECIMAL(4,2) NOT NULL DEFAULT 0,
    rating_count INT NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rating_stats_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE price_change_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2) NOT NULL,
    old_valid_to DATETIME,
    new_valid_from DATETIME NOT NULL,
    changed_by VARCHAR(100),
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_price_log_product
      FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_prices_product_period ON product_prices(product_id, valid_from, valid_to);
CREATE INDEX idx_views_dealer_product_date ON product_views(dealer_id, product_id, viewed_at);
CREATE INDEX idx_orders_dealer_date ON orders(dealer_id, order_date);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_ratings_product ON product_ratings(product_id);
CREATE INDEX idx_price_log_product_date ON price_change_log(product_id, changed_at);

-- =============================================================
-- 2. Съхранени процедури, локални променливи, входни параметри,
--    трансакции, заключване с SELECT ... FOR UPDATE и курсори
-- =============================================================

DELIMITER $$

CREATE PROCEDURE sp_recalculate_order_total(IN p_order_id BIGINT)
BEGIN
    UPDATE orders o
    SET o.total_amount = COALESCE((
        SELECT SUM(oi.line_total)
        FROM order_items oi
        WHERE oi.order_id = p_order_id
    ), 0)
    WHERE o.order_id = p_order_id;
END$$

CREATE PROCEDURE sp_refresh_rating_stats(IN p_product_id INT)
BEGIN
    INSERT INTO product_rating_stats(product_id, avg_rating, rating_count, updated_at)
    SELECT p_product_id,
           COALESCE(ROUND(AVG(rating), 2), 0),
           COUNT(*),
           NOW()
    FROM product_ratings
    WHERE product_id = p_product_id
    ON DUPLICATE KEY UPDATE
       avg_rating = VALUES(avg_rating),
       rating_count = VALUES(rating_count),
       updated_at = NOW();
END$$

CREATE PROCEDURE sp_create_order(
    IN p_dealer_id INT,
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_stock INT DEFAULT 0;
    DECLARE v_price DECIMAL(10,2) DEFAULT 0;
    DECLARE v_discount DECIMAL(5,2) DEFAULT 0;
    DECLARE v_unit_price DECIMAL(10,2) DEFAULT 0;
    DECLARE v_order_id BIGINT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive';
    END IF;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT stock_qty INTO v_stock
    FROM products
    WHERE product_id = p_product_id AND is_active = TRUE
    FOR UPDATE;

    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found or inactive';
    END IF;

    IF v_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock quantity';
    END IF;

    SET v_not_found = FALSE;
    SELECT price INTO v_price
    FROM product_prices
    WHERE product_id = p_product_id AND valid_to IS NULL
    FOR UPDATE;

    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Current price not found';
    END IF;

    SET v_not_found = FALSE;
    SELECT discount_percent INTO v_discount
    FROM dealer_clients
    WHERE dealer_id = p_dealer_id AND is_active = TRUE;

    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dealer not found or inactive';
    END IF;

    SET v_unit_price = ROUND(v_price * (1 - v_discount / 100), 2);

    INSERT INTO orders(dealer_id, order_date, status)
    VALUES (p_dealer_id, NOW(), 'CONFIRMED');

    SET v_order_id = LAST_INSERT_ID();

    UPDATE products
    SET stock_qty = stock_qty - p_quantity
    WHERE product_id = p_product_id;

    INSERT INTO order_items(order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    COMMIT;

    SELECT v_order_id AS created_order_id;
END$$

CREATE PROCEDURE sp_change_product_price(
    IN p_product_id INT,
    IN p_new_price DECIMAL(10,2),
    IN p_changed_by VARCHAR(100)
)
BEGIN
    DECLARE v_old_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_new_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New price must be positive';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT price INTO v_old_price
    FROM product_prices
    WHERE product_id = p_product_id AND valid_to IS NULL
    FOR UPDATE;

    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active price not found';
    END IF;

    IF v_old_price = p_new_price THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The new price is the same as the old price';
    END IF;

    UPDATE product_prices
    SET valid_to = NOW()
    WHERE product_id = p_product_id AND valid_to IS NULL;

    INSERT INTO product_prices(product_id, price, valid_from)
    VALUES (p_product_id, p_new_price, NOW());

    INSERT INTO price_change_log(product_id, old_price, new_price, old_valid_to, new_valid_from, changed_by)
    VALUES (p_product_id, v_old_price, p_new_price, NOW(), NOW(), p_changed_by);

    COMMIT;
END$$

CREATE PROCEDURE sp_top_selling_products(
    IN p_date_from DATE,
    IN p_date_to DATE,
    IN p_limit_rows INT
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_top_selling;

    CREATE TEMPORARY TABLE tmp_top_selling ENGINE = MEMORY AS
    SELECT p.product_id,
           p.sku,
           p.product_name,
           SUM(oi.quantity) AS total_quantity,
           SUM(oi.line_total) AS total_revenue,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    INNER JOIN order_items oi ON oi.order_id = o.order_id
    INNER JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_date >= p_date_from
      AND o.order_date < DATE_ADD(p_date_to, INTERVAL 1 DAY)
      AND o.status IN ('CONFIRMED','COMPLETED')
    GROUP BY p.product_id, p.sku, p.product_name
    HAVING SUM(oi.quantity) > 0
    ORDER BY total_quantity DESC, total_revenue DESC
    LIMIT p_limit_rows;

    SELECT * FROM tmp_top_selling;
    DROP TEMPORARY TABLE IF EXISTS tmp_top_selling;
END$$

CREATE PROCEDURE sp_annual_price_change_report(IN p_year INT)
BEGIN
    DECLARE v_finished BOOLEAN DEFAULT FALSE;
    DECLARE v_product_id INT;
    DECLARE v_product_name VARCHAR(160);
    DECLARE v_first_price DECIMAL(10,2);
    DECLARE v_last_price DECIMAL(10,2);

    DECLARE cur_products CURSOR FOR
        SELECT product_id, product_name
        FROM products
        WHERE is_active = TRUE
        ORDER BY product_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = TRUE;

    DROP TEMPORARY TABLE IF EXISTS tmp_yearly_price_change;
    CREATE TEMPORARY TABLE tmp_yearly_price_change(
        product_id INT,
        product_name VARCHAR(160),
        first_price DECIMAL(10,2),
        last_price DECIMAL(10,2),
        difference_amount DECIMAL(10,2),
        difference_percent DECIMAL(8,2)
    ) ENGINE = MEMORY;

    OPEN cur_products;

    read_loop: LOOP
        FETCH cur_products INTO v_product_id, v_product_name;
        IF v_finished THEN
            LEAVE read_loop;
        END IF;

        SELECT
          (SELECT pp.price
           FROM product_prices pp
           WHERE pp.product_id = v_product_id
             AND YEAR(pp.valid_from) = p_year
           ORDER BY pp.valid_from ASC
           LIMIT 1),
          (SELECT pp.price
           FROM product_prices pp
           WHERE pp.product_id = v_product_id
             AND YEAR(pp.valid_from) = p_year
           ORDER BY pp.valid_from DESC
           LIMIT 1)
        INTO v_first_price, v_last_price;

        IF v_first_price IS NOT NULL AND v_last_price IS NOT NULL THEN
            INSERT INTO tmp_yearly_price_change
            VALUES (
                v_product_id,
                v_product_name,
                v_first_price,
                v_last_price,
                v_last_price - v_first_price,
                CASE
                  WHEN v_first_price > 0
                  THEN ROUND(((v_last_price - v_first_price) / v_first_price) * 100, 2)
                  ELSE NULL
                END
            );
        END IF;
    END LOOP;

    CLOSE cur_products;

    SELECT *
    FROM tmp_yearly_price_change
    ORDER BY ABS(difference_percent) DESC, product_name;

    DROP TEMPORARY TABLE IF EXISTS tmp_yearly_price_change;
END$$

-- =============================================================
-- 3. Тригери
-- =============================================================

CREATE TRIGGER trg_order_items_bi
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_current_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_current_price = NULL;

    IF NEW.unit_price IS NULL THEN
        SELECT price INTO v_current_price
        FROM product_prices
        WHERE product_id = NEW.product_id AND valid_to IS NULL
        LIMIT 1;

        IF v_current_price IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot insert order item without active price';
        END IF;

        SET NEW.unit_price = v_current_price;
    END IF;

    SET NEW.line_total = ROUND(NEW.quantity * NEW.unit_price, 2);
END$$

CREATE TRIGGER trg_order_items_bu
BEFORE UPDATE ON order_items
FOR EACH ROW
BEGIN
    SET NEW.line_total = ROUND(NEW.quantity * NEW.unit_price, 2);
END$$

CREATE TRIGGER trg_order_items_ai
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    CALL sp_recalculate_order_total(NEW.order_id);
END$$

CREATE TRIGGER trg_order_items_au
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
    CALL sp_recalculate_order_total(NEW.order_id);
END$$

CREATE TRIGGER trg_order_items_ad
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    CALL sp_recalculate_order_total(OLD.order_id);
END$$

CREATE TRIGGER trg_product_ratings_ai
AFTER INSERT ON product_ratings
FOR EACH ROW
BEGIN
    CALL sp_refresh_rating_stats(NEW.product_id);
END$$

CREATE TRIGGER trg_product_ratings_au
AFTER UPDATE ON product_ratings
FOR EACH ROW
BEGIN
    CALL sp_refresh_rating_stats(OLD.product_id);
    IF OLD.product_id <> NEW.product_id THEN
        CALL sp_refresh_rating_stats(NEW.product_id);
    END IF;
END$$

CREATE TRIGGER trg_product_ratings_ad
AFTER DELETE ON product_ratings
FOR EACH ROW
BEGIN
    CALL sp_refresh_rating_stats(OLD.product_id);
END$$

DELIMITER ;

-- =============================================================
-- 4. Изгледи
-- =============================================================

CREATE VIEW v_current_product_prices AS
SELECT p.product_id,
       p.sku,
       p.product_name,
       s.supplier_name,
       c.category_name,
       pp.price,
       pp.currency,
       p.stock_qty,
       COALESCE(prs.avg_rating, 0) AS avg_rating,
       COALESCE(prs.rating_count, 0) AS rating_count
FROM products p
INNER JOIN suppliers s ON s.supplier_id = p.supplier_id
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN product_prices pp ON pp.product_id = p.product_id AND pp.valid_to IS NULL
LEFT JOIN product_rating_stats prs ON prs.product_id = p.product_id
WHERE p.is_active = TRUE;

CREATE VIEW v_dealer_order_history AS
SELECT d.dealer_id,
       d.dealer_name,
       o.order_id,
       o.order_date,
       o.status,
       p.sku,
       p.product_name,
       oi.quantity,
       oi.unit_price,
       oi.line_total
FROM dealer_clients d
INNER JOIN orders o ON o.dealer_id = d.dealer_id
INNER JOIN order_items oi ON oi.order_id = o.order_id
INNER JOIN products p ON p.product_id = oi.product_id;

CREATE VIEW v_product_rating_summary AS
SELECT p.product_id,
       p.product_name,
       COUNT(r.rating_id) AS rating_count,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       MIN(r.rating) AS min_rating,
       MAX(r.rating) AS max_rating
FROM products p
LEFT JOIN product_ratings r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name;

-- =============================================================
-- 5. Тестови данни
-- =============================================================

INSERT INTO suppliers(supplier_name, bulstat, email, phone, address) VALUES
('TechnoTrade Ltd.', 'BG100000001', 'sales@technotrade.bg', '02/111111', 'Sofia, Bulgaria'),
('Balkan Components AD', 'BG100000002', 'office@balkan-comp.bg', '032/222222', 'Plovdiv, Bulgaria'),
('Global Office Supplies', 'BG100000003', 'contact@globaloffice.bg', '052/333333', 'Varna, Bulgaria'),
('Stoki Import EOOD', 'BG100000004', 'sales@stoki-import.bg', '082/444444', 'Ruse, Bulgaria');

INSERT INTO categories(category_name, parent_id) VALUES
('Electronics', NULL),
('Office supplies', NULL),
('Tools', NULL),
('Printers', 1),
('Networking', 1);

INSERT INTO products(supplier_id, category_id, sku, product_name, description, unit, stock_qty) VALUES
(1, 1, 'SKU-MOUSE-A', 'Wireless mouse A', 'Wireless optical mouse', 'pcs', 150),
(1, 1, 'SKU-KEYB-B', 'Mechanical keyboard B', 'Keyboard with BG/EN layout', 'pcs', 60),
(2, 4, 'SKU-PRN-100', 'Laser printer 100', 'Office laser printer', 'pcs', 25),
(2, 5, 'SKU-ROUTER-X', 'Router X', 'Dual-band wireless router', 'pcs', 80),
(4, 3, 'SKU-DRILL-18V', 'Cordless drill 18V', 'Battery powered drill', 'pcs', 40),
(3, 2, 'SKU-PAPER-A4', 'Copy paper A4', '500 sheets pack', 'pack', 300);

INSERT INTO dealer_clients(dealer_name, bulstat, email, phone, address, discount_percent) VALUES
('Sofia Dealer OOD', 'BG200000001', 'orders@sofiadealer.bg', '02/555555', 'Sofia, Bulgaria', 0),
('Varna Trade EOOD', 'BG200000002', 'buy@varnatrade.bg', '052/555555', 'Varna, Bulgaria', 2.50),
('Plovdiv Pro AD', 'BG200000003', 'sales@plovdivpro.bg', '032/555555', 'Plovdiv, Bulgaria', 5.00),
('Ruse Market OOD', 'BG200000004', 'office@rusemarket.bg', '082/555555', 'Ruse, Bulgaria', 0);

INSERT INTO product_prices(product_id, price, valid_from, valid_to) VALUES
(1, 25.00, '2023-01-01 00:00:00', '2023-12-31 23:59:59'),
(1, 30.00, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
(1, 34.00, '2025-01-01 00:00:00', NULL),
(2, 50.00, '2024-01-01 00:00:00', '2024-06-30 23:59:59'),
(2, 55.00, '2024-07-01 00:00:00', NULL),
(3, 430.00, '2024-01-01 00:00:00', '2025-02-28 23:59:59'),
(3, 450.00, '2025-03-01 00:00:00', NULL),
(4, 110.00, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
(4, 120.00, '2025-01-01 00:00:00', NULL),
(5, 220.00, '2025-01-01 00:00:00', NULL),
(6, 10.00, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
(6, 12.50, '2025-01-01 00:00:00', NULL);

INSERT INTO product_views(dealer_id, product_id, viewed_at, ip_address) VALUES
(1, 1, '2025-01-12 10:05:00', '192.168.0.10'),
(1, 3, '2025-01-12 10:10:00', '192.168.0.10'),
(2, 2, '2025-02-02 11:00:00', '192.168.0.11'),
(2, 3, '2025-02-02 11:04:00', '192.168.0.11'),
(3, 5, '2025-03-10 09:30:00', '192.168.0.12'),
(4, 1, '2025-01-24 13:20:00', '192.168.0.13'),
(4, 6, '2025-01-24 13:25:00', '192.168.0.13');

INSERT INTO orders(dealer_id, order_date, status) VALUES
(1, '2024-02-10 09:00:00', 'COMPLETED'),
(2, '2024-07-15 12:30:00', 'COMPLETED'),
(1, '2025-03-20 10:15:00', 'COMPLETED'),
(3, '2025-04-05 15:40:00', 'CONFIRMED'),
(4, '2025-01-25 14:10:00', 'COMPLETED');

INSERT INTO order_items(order_id, product_id, quantity, unit_price) VALUES
(1, 1, 10, 30.00),
(1, 6, 50, 12.00),
(2, 2, 5, 55.00),
(2, 3, 1, 430.00),
(3, 3, 2, 450.00),
(3, 4, 5, 120.00),
(4, 5, 1, 220.00),
(5, 1, 15, 34.00),
(5, 6, 100, 12.50);

INSERT INTO product_ratings(dealer_id, product_id, rating, comment, rated_at) VALUES
(1, 1, 5, 'Много добра периферия.', '2025-02-01 10:00:00'),
(2, 3, 4, 'Надежден принтер.', '2025-03-01 11:00:00'),
(1, 3, 5, 'Добро качество за цената.', '2025-04-01 12:00:00'),
(4, 1, 4, 'Бърза доставка.', '2025-02-15 14:00:00'),
(3, 5, 3, 'Средна оценка.', '2025-04-08 16:00:00');

-- =============================================================
-- 6. Заявки за демонстрация на материала
-- =============================================================

-- 6.1 SELECT с логически оператори AND / OR / NOT / BETWEEN / LIKE
SELECT product_id, sku, product_name, stock_qty
FROM products
WHERE (stock_qty BETWEEN 40 AND 200 AND is_active = TRUE)
   OR (product_name LIKE '%printer%' AND NOT supplier_id = 3);

-- 6.2 Агрегатна функция, GROUP BY и HAVING
SELECT s.supplier_name,
       COUNT(p.product_id) AS products_count,
       SUM(p.stock_qty) AS total_stock,
       ROUND(AVG(p.stock_qty), 2) AS avg_stock
FROM suppliers s
LEFT JOIN products p ON p.supplier_id = s.supplier_id
GROUP BY s.supplier_id, s.supplier_name
HAVING COUNT(p.product_id) >= 1
ORDER BY products_count DESC;

-- 6.3 INNER JOIN: активни цени на стоки по доставчици
SELECT p.sku, p.product_name, s.supplier_name, pp.price, pp.currency
FROM products p
INNER JOIN suppliers s ON s.supplier_id = p.supplier_id
INNER JOIN product_prices pp ON pp.product_id = p.product_id AND pp.valid_to IS NULL
ORDER BY s.supplier_name, p.product_name;

-- 6.4 LEFT OUTER JOIN: всички стоки, дори без рейтинг
SELECT p.product_name, prs.avg_rating, prs.rating_count
FROM products p
LEFT JOIN product_rating_stats prs ON prs.product_id = p.product_id
ORDER BY p.product_name;

-- 6.5 RIGHT OUTER JOIN: всички дилъри и разгледаните от тях стоки
SELECT d.dealer_name, p.product_name, pv.viewed_at
FROM product_views pv
RIGHT OUTER JOIN dealer_clients d ON d.dealer_id = pv.dealer_id
LEFT JOIN products p ON p.product_id = pv.product_id
ORDER BY d.dealer_name, pv.viewed_at;

-- 6.6 CROSS JOIN: възможни комбинации дилър - категория за маркетингови кампании
SELECT d.dealer_name, c.category_name
FROM dealer_clients d
CROSS JOIN categories c
WHERE c.parent_id IS NULL
ORDER BY d.dealer_name, c.category_name;

-- 6.7 SELF JOIN: стоки от един и същи доставчик
SELECT p1.product_name AS product_1, p2.product_name AS product_2, s.supplier_name
FROM products p1
INNER JOIN products p2 ON p1.supplier_id = p2.supplier_id AND p1.product_id < p2.product_id
INNER JOIN suppliers s ON s.supplier_id = p1.supplier_id;

-- 6.8 FULL OUTER JOIN в MySQL чрез UNION от LEFT и RIGHT JOIN
SELECT d.dealer_name, o.order_id, o.order_date
FROM dealer_clients d
LEFT JOIN orders o ON o.dealer_id = d.dealer_id
UNION
SELECT d.dealer_name, o.order_id, o.order_date
FROM dealer_clients d
RIGHT JOIN orders o ON o.dealer_id = d.dealer_id;

-- 6.9 Вложен SELECT: стоки с цена над средната активна цена
SELECT p.product_name, pp.price
FROM products p
INNER JOIN product_prices pp ON pp.product_id = p.product_id AND pp.valid_to IS NULL
WHERE pp.price > (
    SELECT AVG(price)
    FROM product_prices
    WHERE valid_to IS NULL
)
ORDER BY pp.price DESC;

-- 6.10 JOIN + агрегатна функция: най-продавани стоки за период
SET @date_from = '2025-01-01';
SET @date_to = '2025-12-31';

SELECT p.sku,
       p.product_name,
       SUM(oi.quantity) AS sold_quantity,
       SUM(oi.line_total) AS revenue
FROM orders o
INNER JOIN order_items oi ON oi.order_id = o.order_id
INNER JOIN products p ON p.product_id = oi.product_id
WHERE o.order_date BETWEEN @date_from AND @date_to
  AND o.status IN ('CONFIRMED','COMPLETED')
GROUP BY p.product_id, p.sku, p.product_name
HAVING SUM(oi.quantity) >= 1
ORDER BY sold_quantity DESC, revenue DESC;

-- 6.11 Използване на изглед
SELECT *
FROM v_current_product_prices
ORDER BY avg_rating DESC, product_name;

-- 6.12 Извикване на процедури
CALL sp_top_selling_products('2025-01-01', '2025-12-31', 5);
CALL sp_annual_price_change_report(2024);
CALL sp_create_order(1, 2, 3);
CALL sp_change_product_price(2, 59.90, 'admin');
