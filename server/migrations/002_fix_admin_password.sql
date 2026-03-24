-- 修复默认管理员密码（明文：admin123）。
-- 说明：Docker 首次启动时才会跑 001_init；已有数据卷时改 001 不会重跑，需手动执行本脚本一次。
-- 用法示例：mysql -h127.0.0.1 -P3307 -umoment -pmoment_password moment < server/migrations/002_fix_admin_password.sql

USE `moment`;

UPDATE `users`
SET `password` = '$2a$10$uKzWOxUe901YJhGwe540l.7O3vRneTmgaaHMmRVagd8PMrrbaxIzi'
WHERE `username` = 'admin';

-- 若缺少角色关联，管理登录会提示「账号已被禁用」；此处补全 super_admin
INSERT IGNORE INTO `user_roles` (`user_id`, `role_id`)
SELECT u.`id`, r.`id`
FROM `users` u
CROSS JOIN `roles` r
WHERE u.`username` = 'admin' AND r.`code` = 'super_admin';
