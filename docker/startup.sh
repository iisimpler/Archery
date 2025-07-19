#!/bin/bash
set -e

# 重定向所有echo到日志文件
exec > >(tee -a /opt/archery/logs/startup.log) 2>&1

echo "=== Archery 轻量化启动脚本 ==="
cd /opt/archery

echo "1. 激活Python虚拟环境"
source /opt/venv4archery/bin/activate

echo "2. 配置Gunicorn参数"
echo "   - 绑定地址: ${GUNICORN_BIND}"
echo "   - 工作进程: ${GUNICORN_WORKERS}个"
echo "   - 超时时间: ${GUNICORN_TIMEOUT}秒"

echo "3. 收集Django静态文件"
python manage.py collectstatic --noinput --verbosity=0

echo "4. 启动Supervisor管理的异步任务队列"
/usr/bin/supervisord -c /opt/archery/conf/supervisord.conf

echo "5. 启动Gunicorn应用服务器"
echo "   容器监听端口: 8888"
echo "   静态文件服务: WhiteNoise中间件自动处理"
echo "   访问地址: http://localhost:8888"

exec gunicorn -w ${GUNICORN_WORKERS} -b ${GUNICORN_BIND} --timeout ${GUNICORN_TIMEOUT} archery.wsgi:application

