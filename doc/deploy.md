# 拾光记 - 部署指南

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+

## 快速部署

### 1. 克隆项目

```bash
git clone <repository-url>
cd moment
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，修改必要的配置
```

### 3. 启动服务

```bash
# 构建并启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 4. 验证服务

- 后端健康检查: `http://localhost:8080/health`
- 管理端: `http://localhost`

## 服务说明

| 服务 | 端口 | 说明 |
|------|------|------|
| mysql | 3306 | MySQL 8.0 数据库 |
| redis | 6379 | Redis 7 缓存 |
| server | 8080 | Go 后端服务 |
| admin | 80 | Vue 管理端 |

## 数据持久化

数据存储在 Docker volume 中:
- `mysql_data` - MySQL 数据
- `redis_data` - Redis 数据
- `uploads_data` - 上传的文件
- `logs_data` - 日志文件

## 停止服务

```bash
docker-compose down

# 删除数据卷（谨慎操作）
docker-compose down -v
```

## 生产环境注意事项

1. **修改 JWT Secret**: 在 `.env` 中设置强密码
2. **数据库密码**: 使用强密码并定期更换
3. **HTTPS**: 使用 Nginx 反向代理配置 HTTPS
4. **定期备份**: 备份数据库和数据卷

## Nginx HTTPS 配置示例

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 管理端
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    # API 代理
    location /api/ {
        proxy_pass http://moment-server:8080/;
    }
}
```
