-- 修复「昵称、角色名、权限名」等中文乱码（典型：UTF-8 内容曾按 latin1 写入或会话字符集错误）。
-- 1) 先重启/重连 Go 服务（DSN 已带 utf8mb4 + utf8mb4_unicode_ci）。
-- 2) 用 UTF-8 客户端执行本脚本，避免再次写坏：
--    mysql --default-character-set=utf8mb4 -h127.0.0.1 -uroot -p moment < server/migrations/003_fix_chinese_mojibake.sql

USE `moment`;

-- 角色（按 code 更新，与 001_init 种子一致）
UPDATE `roles` SET `name` = '超级管理员', `description` = '拥有系统所有权限' WHERE `code` = 'super_admin';
UPDATE `roles` SET `name` = '普通用户', `description` = '普通用户角色' WHERE `code` = 'user';
UPDATE `roles` SET `name` = '管理员', `description` = '后台管理员角色' WHERE `code` = 'admin';

-- 默认管理员昵称
UPDATE `users` SET `nickname` = '超级管理员' WHERE `username` = 'admin';

-- 权限名称（按 code）
UPDATE `permissions` SET `name` = '系统管理' WHERE `code` = 'system';
UPDATE `permissions` SET `name` = '用户管理' WHERE `code` = 'system:user';
UPDATE `permissions` SET `name` = '角色管理' WHERE `code` = 'system:role';
UPDATE `permissions` SET `name` = '权限管理' WHERE `code` = 'system:permission';
UPDATE `permissions` SET `name` = '日志管理' WHERE `code` = 'system:log';
UPDATE `permissions` SET `name` = '时光管理' WHERE `code` = 'moment';
UPDATE `permissions` SET `name` = '查看时光' WHERE `code` = 'moment:list';
UPDATE `permissions` SET `name` = '添加时光' WHERE `code` = 'moment:add';
UPDATE `permissions` SET `name` = '编辑时光' WHERE `code` = 'moment:edit';
UPDATE `permissions` SET `name` = '删除时光' WHERE `code` = 'moment:delete';
