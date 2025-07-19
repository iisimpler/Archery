#!/bin/bash
set -e

echo "================================================================================================"
echo "安装SQL审核和优化工具链（仅二进制文件）"
echo "================================================================================================"

# 设置工作目录
cd /opt

# 安装SQLAdvisor - SQL索引优化建议工具
echo "安装SQLAdvisor..."
curl -o sqladvisor -L https://github.com/LeoQuote/SQLAdvisor/releases/download/v2.1/sqladvisor-linux-amd64
chmod +x sqladvisor
curl -o sqlparser.tar.gz -L https://github.com/LeoQuote/SQLAdvisor/releases/download/v2.1/sqlparser-linux-amd64.tar.gz
tar -xzf sqlparser.tar.gz
mv sqlparser /usr/local/sqlparser
rm -rf sqlparser*
echo "SQLAdvisor安装完成"

# 安装SOAR - SQL优化分析报告工具
echo "安装SOAR..."
curl -L -q https://github.com/XiaoMi/soar/releases/download/${SOAR_VERSION}/soar.linux-amd64 -o soar
chmod +x soar
echo "SOAR安装完成"

# 安装my2sql - MySQL binlog解析工具
echo "安装my2sql..."
curl -L -q https://raw.githubusercontent.com/liuhr/my2sql/master/releases/centOS_release_7.x/my2sql -o my2sql
chmod +x my2sql
echo "my2sql安装完成"

# 安装MongoDB客户端
echo "安装MongoDB客户端..."
curl -L -q -o mongodb-linux-x86_64-rhel70-3.6.20.tgz https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-3.6.20.tgz
tar -xf mongodb-linux-x86_64-rhel70-3.6.20.tgz
mv mongodb-linux-x86_64-rhel70-3.6.20/bin/mongo /usr/local/bin/
chmod +x /usr/local/bin/mongo
rm -rf mongodb-linux-x86_64-rhel70-3.6.20*
echo "MongoDB客户端安装完成"

# 安装Oracle客户端
echo "安装Oracle客户端..."
mkdir -p /opt/oracle
cd /opt/oracle
curl -q -L -o oracle-install.zip https://download.oracle.com/otn_software/linux/instantclient/1921000/instantclient-basic-linux.x64-19.21.0.0.0dbru.zip
unzip oracle-install.zip
echo "/opt/oracle/instantclient_19_21" > /etc/ld.so.conf.d/oracle-instantclient.conf
ldconfig
rm -rf oracle-install.zip
cd /opt
echo "Oracle客户端安装完成"

echo "================================================================================================"
echo "二进制工具安装完成"
echo "================================================================================================" 