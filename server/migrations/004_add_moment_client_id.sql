-- 为 moments 增加 client_id 并建立 (user_id, client_id) 唯一约束。
-- 作用：客户端同步创建时携带本地 UUID，服务端可对重复重试做幂等返回，避免生成重复记录。
-- 用法示例：mysql --default-character-set=utf8mb4 -h127.0.0.1 -P3307 -umoment -pmoment_password moment < server/migrations/004_add_moment_client_id.sql

USE `moment`;

ALTER TABLE `moments`
    ADD COLUMN `client_id` VARCHAR(64) DEFAULT NULL COMMENT '客户端本地记录ID（用于幂等创建）' AFTER `user_id`;

ALTER TABLE `moments`
    ADD UNIQUE KEY `uk_moments_user_client_id` (`user_id`, `client_id`);
