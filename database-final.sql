-- 使用者
CREATE TABLE users (
  user_id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  account VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL


);

-- 分類
CREATE TABLE categories (
  category_id INT PRIMARY KEY AUTO_INCREMENT,
  category_name VARCHAR(50) NOT NULL UNIQUE
);

-- 遺失物
CREATE TABLE items (
  item_id INT PRIMARY KEY AUTO_INCREMENT,
  item_name VARCHAR(100) NOT NULL,
  description TEXT,
  found_date DATE NOT NULL,
  image_url VARCHAR(255),
  category_id INT NOT NULL,
  user_id INT NOT NULL,
  item_status ENUM('未認領', '已認領', '已過期') DEFAULT '未認領' NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 認領紀錄
CREATE TABLE claims (
  claim_id INT PRIMARY KEY AUTO_INCREMENT,
  item_id INT NOT NULL,
  user_id INT NOT NULL,
  claim_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  claim_status ENUM('待審核', '通過', '駁回') DEFAULT '待審核' NOT NULL,
  reject_reason TEXT,
  reviewed_at DATETIME DEFAULT NULL,
  FOREIGN KEY (item_id) REFERENCES items(item_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 使用者
INSERT INTO users (name, email, account, password) VALUES
('張小美', 'user1@mail.com', 'zhangmei', 'pass123'),
('李小華', 'user2@mail.com', 'xiaohua', 'pass234'),
('王大明', 'user3@mail.com', 'daming', 'pass345');

-- 分類
INSERT INTO categories (category_name) VALUES
('電子產品'),
('個人配件'),
('生活用品');

-- 遺失物
INSERT INTO items (item_name, description, found_date, image_url, category_id, user_id, item_status) VALUES
('AirPods 耳機', '白色充電盒', '2025-06-10', 'http://example.com/img1.jpg', 1, 1, '未認領'),
('黑色錢包', '內含學生證與現金', '2025-06-01', 'http://example.com/wallet.jpg', 2, 2, '已認領'),
('水壺', '紅色保溫瓶', '2025-04-01', 'http://example.com/bottle.jpg', 3, 3, '已過期'),
('藍芽滑鼠', '底部有貼紙', '2025-06-15', 'http://example.com/mouse.jpg', 1, 1, '未認領');

-- 認領紀錄
INSERT INTO claims (item_id, user_id, claim_date, claim_status, reject_reason, reviewed_at) VALUES
(2, 3, '2025-06-05 14:00:00', '通過', NULL, '2025-06-06 09:00:00'),
(1, 2, '2025-06-11 09:30:00', '駁回', '描述不符', '2025-06-12 10:00:00'),
(4, 3, '2025-06-16 13:00:00', '待審核', NULL, NULL);

-- 遺失物狀態索引
CREATE INDEX idx_items_status ON items(item_status);

-- 認領狀態索引
CREATE INDEX idx_claims_status ON claims(claim_status);



BEGIN;

-- 步驟一：更新認領紀錄為「通過」
UPDATE claims
SET claim_status = '通過',
    reviewed_at = NOW(),
    reject_reason = NULL
WHERE claim_id = 1;

-- 步驟二：將該筆認領紀錄對應的物品設為「已認領」
UPDATE items
SET item_status = '已認領'
WHERE item_id = (
  SELECT item_id FROM claims WHERE claim_id = 1
);

-- 若以上皆成功，則提交
COMMIT;

-- 查詢每類別遺失物件數量，且只顯示遺失物數量超過 1 的類別
SELECT c.category_name, COUNT(*) AS item_count
FROM items i
JOIN categories c ON i.category_id = c.category_id
GROUP BY c.category_name
HAVING item_count > 1;

-- 查詢所有物品與其認領資訊
-- 建立VIEW
CREATE OR REPLACE VIEW view_item_claim AS
SELECT
  i.item_id,
  i.item_name,
  i.item_status,
  u.name AS uploader_name,
  cl.claim_status,
  cl.claim_date
FROM items i
JOIN users u ON i.user_id = u.user_id
LEFT JOIN claims cl ON i.item_id = cl.item_id;

-- 查詢VIEW
SELECT * FROM view_item_claim

-- 查詢某類別的統計數量
DELIMITER $$

CREATE PROCEDURE count_items_by_category(IN p_category_id INT)
BEGIN
  SELECT COUNT(*) AS total_items
  FROM items
  WHERE category_id = p_category_id;
END$$

DELIMITER ;

-- 查詢分類1的物品總數
CALL count_items_by_category(1);

-- 若物品超過保管期限（found_date + 1 個月 < 現在時間）
-- 則自動將 item_status 設為 '已過期'
DELIMITER $$

CREATE TRIGGER auto_expire_item
BEFORE UPDATE ON items
FOR EACH ROW
BEGIN
  IF DATE_ADD(NEW.found_date, INTERVAL 1 MONTH) < CURRENT_DATE THEN
    SET NEW.item_status = '已過期';
  END IF;
END$$

DELIMITER ;
-- 查詢所有未認領物品
SELECT * FROM items WHERE item_status = '未認領';

-- 嘗試插入不存在的 user_id（預期報錯）
INSERT INTO claims (item_id, user_id) VALUES (1, 999);

BEGIN;

-- 正常步驟一
UPDATE claims
SET claim_status = '通過',
    reviewed_at = NOW(),
    reject_reason = NULL
WHERE claim_id = 3;

-- 故意錯誤的步驟二（例如寫錯欄位 item_idd）
UPDATE items
SET item_status = '已認領'
WHERE item_idd = (
  SELECT item_id FROM claims WHERE claim_id = 3
);

-- 查詢驗證（預期 claim_status 仍為"待審核"）
SELECT * FROM claims WHERE claim_id = 3;

-- 快速新增多筆"未認領"資料
INSERT INTO items (item_name, description, found_date, image_url, category_id, user_id, item_status)
SELECT 
  CONCAT('物品_', t1.id * 100 + t2.id),
  '模擬資料',
  CURDATE(),
  'http://example.com/img.jpg',
  1,
  1,
  '未認領'
FROM 
  (SELECT @row := @row + 1 AS id FROM information_schema.columns, (SELECT @row := 0) x LIMIT 10) t1,
  (SELECT @row2 := @row2 + 1 AS id FROM information_schema.columns, (SELECT @row2 := 0) y LIMIT 100) t2;

-- 移除索引（若已存在）
DROP INDEX IF EXISTS idx_item_status ON items;

--  啟用查詢計時
SET profiling = 1;

-- 查詢未認領物品
SELECT * FROM items WHERE item_status = '未認領';

-- 查詢耗時
SHOW PROFILES;

-- 建立索引
CREATE INDEX idx_item_status ON items(item_status);

-- 查詢未認領物品
SELECT * FROM items WHERE item_status = '未認領';

-- 查詢耗時
SHOW PROFILES;
