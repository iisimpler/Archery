# Archery Docker 轻量化构建指南

## 🚀 快速开始

### 构建镜像
```bash
# 在项目根目录执行
docker build -t archery:latest .
```

### 运行容器

#### 基础运行（需要外部Nginx）
```bash
# 基础运行 - 暴露8888端口，需要外部Nginx反向代理
docker run -d -p 8888:8888 --name archery archery:latest

# 带配置文件挂载
docker run -d \
  -p 8888:8888 \
  -v /path/to/config:/opt/archery/conf \
  -v /path/to/logs:/opt/archery/logs \
  --name archery archery:latest
```

#### 完整部署（推荐使用Docker Compose）
```bash
# 使用提供的docker-compose.yml
docker-compose up -d
```

### 访问应用
- **容器端口**: 8888 (Gunicorn)
- **需要配置**: 外部Nginx反向代理
- **健康检查**: `curl -f http://localhost:8888/`

## 📋 架构变更说明

### 🆕 v2.1 轻量化架构
- ❌ **移除内置Nginx**: 容器专注应用服务
- ✅ **配置文件外置**: 支持挂载配置目录
- ✅ **环境变量配置**: 关键参数可通过环境变量调整
- ✅ **更小镜像**: 减少不必要的依赖

### 🏗️ 新架构对比
```
旧架构: 外部请求 → 容器Nginx:9123 → 内部Gunicorn:8888
新架构: 外部请求 → 外部Nginx → 容器Gunicorn:8888
```

## 📁 配置文件管理

### 配置目录结构
```
/path/to/config/
├── supervisord.conf          # Supervisor配置（可选）
└── settings/                 # Django配置（可选）
    ├── production.py
    └── logging.conf
```

### 配置优先级
1. **外置配置文件** (挂载到 `/opt/archery/conf/`)
2. **环境变量** 
3. **容器默认配置**

### 环境变量配置
| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `GUNICORN_WORKERS` | Gunicorn工作进程数 | 4 |
| `GUNICORN_TIMEOUT` | 请求超时时间(秒) | 600 |
| `GUNICORN_BIND` | 绑定地址 | 0.0.0.0:8888 |
| `TZ` | 时区设置 | Asia/Shanghai |

## 🌐 外部Nginx配置

### 最小配置示例
```nginx
upstream archery_backend {
    server 127.0.0.1:8888;
}

server {
    listen 80;
    server_name archery.yourdomain.com;
    
    location / {
        proxy_pass http://archery_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 完整配置
- 📄 详细配置请参考: `examples/nginx.conf`
- 🔒 HTTPS配置包含在示例中
- 📊 包含负载均衡配置

## 🐳 Docker Compose 部署

### 一键部署
```bash
# 下载示例配置
curl -O https://raw.githubusercontent.com/your-repo/archery/master/examples/docker-compose.yml

# 调整配置文件中的环境变量和挂载路径
vim docker-compose.yml

# 启动服务
docker-compose up -d
```

### 服务组件
- **archery**: 主应用服务
- **mysql**: 数据库服务
- **redis**: 缓存服务  
- **nginx**: 反向代理（可选）

## 📦 配置文件示例

### Supervisor配置
```bash
# 下载示例配置
mkdir -p config
curl -o config/supervisord.conf \
  https://raw.githubusercontent.com/your-repo/archery/master/examples/supervisord.conf
```

## 🔧 高级配置

### 多实例部署
```yaml
# docker-compose.yml 示例
services:
  archery1:
    image: archery:latest
    ports:
      - "8881:8888"
  
  archery2:
    image: archery:latest  
    ports:
      - "8882:8888"
```

### 资源限制
```yaml
services:
  archery:
    image: archery:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

## 🐛 故障排除

### 查看日志
```bash
# 容器日志
docker logs archery

# 应用日志（如果挂载了日志目录）
tail -f /path/to/logs/supervisord.log
tail -f /path/to/logs/qcluster.log

# Nginx日志（如果使用docker-compose）
docker logs archery_nginx
```

### 调试模式
```bash
# 进入容器调试
docker exec -it archery bash

# 检查配置文件
docker exec archery cat /opt/archery/conf/supervisord.conf

# 检查服务状态
docker exec archery supervisorctl status
```

### 常见问题

#### 1. 外部无法访问
- ✅ 检查外部Nginx配置
- ✅ 确认容器端口映射
- ✅ 检查防火墙设置

#### 2. 配置文件不生效
- ✅ 确认挂载路径正确
- ✅ 检查文件权限
- ✅ 重启容器应用新配置

#### 3. 数据库连接失败
- ✅ 检查数据库服务状态
- ✅ 确认网络连接
- ✅ 验证连接参数

## 📊 性能优化

### Gunicorn调优
```bash
# 根据CPU核心数调整工作进程
export GUNICORN_WORKERS=$(($(nproc) * 2 + 1))

# 增加超时时间（适用于复杂查询）
export GUNICORN_TIMEOUT=900
```

### 资源监控
```bash
# 监控容器资源使用
docker stats archery

# 监控Supervisor管理的进程
docker exec archery supervisorctl status
```

## 🔄 更新升级

### 镜像更新
```bash
# 停止当前容器
docker stop archery

# 拉取新镜像
docker pull archery:latest

# 重启容器（配置文件挂载会保留）
docker run -d \
  -p 8888:8888 \
  -v /path/to/config:/opt/archery/conf \
  -v /path/to/logs:/opt/archery/logs \
  --name archery archery:latest
```

### 配置迁移
- 新版本配置文件向后兼容
- 建议备份配置文件后升级
- 参考release notes了解配置变更 