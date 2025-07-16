# ================================================================================================
# Archery 数据库审核平台 - 轻量化Docker镜像构建文件
# 
# 功能说明：
# - 集成SQL审核工具：SQLAdvisor、SOAR、my2sql等
# - 支持多种数据库：MySQL、PostgreSQL、Oracle、MongoDB、ClickHouse等
# - 轻量化设计：移除内置Nginx，由外部反向代理
# - 配置外置：支持挂载配置文件目录
# 
# 构建命令：docker build -t archery:latest .
# 运行命令：docker run -d -p 8888:8888 -v /path/to/config:/opt/archery/conf --name archery archery:latest
# ================================================================================================

ARG PYTHON_BASE_IMAGE=python:3.11-slim-bullseye
FROM ${PYTHON_BASE_IMAGE} AS builder

# ================================================================================================
# 阶段1：编译阶段 - 只包含编译工具和Python依赖构建
# ================================================================================================

# 设置环境变量
ENV SOAR_VERSION=0.11.0 \
    TZ=Asia/Shanghai \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# 设置工作目录
WORKDIR /opt

# 只安装编译依赖（运行时依赖在runtime阶段安装）
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础编译工具
    build-essential \
    gcc \
    g++ \
    python3-dev \
    pkg-config \
    curl \
    wget \
    unzip \
    # 工具安装脚本需要的依赖
    gnupg2 \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    # LDAP编译依赖
    libldap2-dev \
    libsasl2-dev \
    # Kerberos编译依赖（解决krb5-config not found错误）
    libkrb5-dev \
    # 其他编译依赖
    libffi-dev \
    libssl-dev \
    libmariadb-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建Python虚拟环境
RUN python3 -m venv venv4archery

# 设置LDAP编译环境变量
ENV LDFLAGS="-L/usr/lib/x86_64-linux-gnu -L/usr/lib" \
    CPPFLAGS="-I/usr/include -I/usr/include/ldap" \
    C_INCLUDE_PATH="/usr/include:/usr/include/ldap" \
    LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/lib"

# 先复制requirements.txt以优化缓存利用
COPY requirements.txt .

# 激活虚拟环境并安装Python依赖
RUN . venv4archery/bin/activate && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir "redis>=4.1.0" && \
    pip install --no-cache-dir "psutil>=5.9.0"

# ================================================================================================
# 使用安装脚本一次性安装所有工具（减少Docker层数）
# ================================================================================================

# 复制并执行工具安装脚本
COPY ./docker/install-tools.sh /tmp/install-tools.sh
RUN chmod +x /tmp/install-tools.sh && \
    /tmp/install-tools.sh && \
    rm -f /tmp/install-tools.sh

# ================================================================================================
# 阶段2：应用构建阶段
# ================================================================================================

FROM ${PYTHON_BASE_IMAGE} AS runtime

# 安装运行时系统依赖（只安装运行时库，不安装开发包）
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础运行时工具
    curl \
    gnupg2 \
    lsb-release \
    supervisor \
    ca-certificates \
    apt-transport-https \
    # 数据库客户端
    mariadb-client \
    # LDAP运行时库（注意：只要运行时库，不要-dev包）
    libldap-2.4-2 \
    libsasl2-2 \
    libsasl2-modules-ldap \
    # Kerberos运行时库
    libkrb5-3 \
    libgssapi-krb5-2 \
    # 其他运行时库
    libssl1.1 \
    libffi7 \
    libmariadb3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装MS SQL Server ODBC驱动（runtime阶段重新安装）
RUN curl -q -L https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/trusted.gpg.d/microsoft.asc && \
    curl -q -L https://packages.microsoft.com/config/debian/11/prod.list -o /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装Percona工具包（runtime阶段重新安装）
RUN curl -O https://repo.percona.com/apt/percona-release_latest.generic_all.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends ./percona-release_latest.generic_all.deb && \
    apt-get update && \
    percona-release setup -y pdps-8.0 && \
    apt-get install -y --no-install-recommends percona-toolkit && \
    percona-release disable pdps-8.0 && \
    rm -f percona-release_latest.generic_all.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从builder阶段复制已编译的Python虚拟环境和工具
COPY --from=builder /opt/venv4archery /opt/venv4archery
COPY --from=builder /opt/sqladvisor /opt/sqladvisor
COPY --from=builder /opt/soar /opt/soar  
COPY --from=builder /opt/my2sql /opt/my2sql
COPY --from=builder /opt/oracle /opt/oracle
COPY --from=builder /usr/local /usr/local
COPY --from=builder /etc/ld.so.conf.d/oracle-instantclient.conf /etc/ld.so.conf.d/

# 更新动态链接器缓存（确保Oracle客户端能正确链接）
RUN ldconfig

# 设置环境变量
ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv4archery/bin:$PATH" \
    GUNICORN_WORKERS=4 \
    GUNICORN_TIMEOUT=600 \
    GUNICORN_BIND=0.0.0.0:8888

# 设置工作目录
WORKDIR /opt/archery

# 创建必要的目录
RUN mkdir -p /opt/archery/logs /opt/archery/conf

# ================================================================================================
# 复制配置文件模板（先复制配置文件以优化缓存）
# ================================================================================================

# 拷贝默认Supervisor配置文件
COPY ./docker/supervisord.conf /opt/archery/conf/supervisord.conf

# 拷贝启动脚本并设置执行权限
COPY ./docker/startup.sh /opt/archery/startup.sh
RUN chmod +x /opt/archery/startup.sh

# ================================================================================================
# 移动SQL工具到插件目录
# ================================================================================================

RUN mkdir -p /opt/archery/src/plugins && \
    mv /opt/sqladvisor /opt/archery/src/plugins/ && \
    mv /opt/soar /opt/archery/src/plugins/ && \
    mv /opt/my2sql /opt/archery/src/plugins/ && \
    chmod +x /opt/archery/src/plugins/sqladvisor && \
    chmod +x /opt/archery/src/plugins/soar && \
    chmod +x /opt/archery/src/plugins/my2sql

# 为SQLAdvisor创建MySQL库软链接
RUN ln -sf /usr/lib/x86_64-linux-gnu/libmariadb.so.3 /usr/lib/x86_64-linux-gnu/libmysqlclient.so.18

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ================================================================================================
# 最后复制应用源码（优化缓存利用 - 代码变更不会影响前面的层）
# ================================================================================================

# 复制项目源码
COPY . /opt/archery/

# ================================================================================================
# 容器运行配置
# ================================================================================================

# 暴露Gunicorn端口（移除nginx端口）
EXPOSE 8888

# 创建配置文件挂载点
VOLUME ["/opt/archery/conf", "/opt/archery/logs"]

# 设置健康检查（调整为gunicorn端口）
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8888/ || exit 1

# 设置容器入口点
ENTRYPOINT ["bash", "/opt/archery/startup.sh"]

# ================================================================================================
# 构建信息和使用说明
# ================================================================================================

LABEL maintainer="Archery Team" \
      version="2.1" \
      description="Archery数据库审核平台 - 轻量化容器，支持配置外置" \
      usage="docker run -d -p 8888:8888 -v /path/to/config:/opt/archery/conf --name archery archery:latest"

# 构建完成标记
RUN echo "=== Archery 轻量化Docker镜像构建完成 ===" && \
    echo "包含工具: SQLAdvisor, SOAR, my2sql, pt-archiver" && \
    echo "支持数据库: MySQL, PostgreSQL, Oracle, MongoDB, ClickHouse等" && \
    echo "Web架构: Gunicorn + Django + Redis（无内置Nginx）" && \
    echo "监听端口: 8888" && \
    echo "配置外置: 挂载 /opt/archery/conf 目录" && \
    echo "=========================================" 