#!/bin/bash

# ================================================================================================
# Archery Docker 镜像构建脚本
# 
# 使用方法：
#   ./build.sh                    # 构建最新版本镜像
#   ./build.sh --tag v1.0.0       # 构建指定标签版本  
#   ./build.sh --clean            # 清理构建缓存后构建
#   ./build.sh --help             # 显示帮助信息
# ================================================================================================

set -e

# 默认配置
IMAGE_NAME="iisimpler/archery"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CLEAN_BUILD=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
Archery Docker 镜像构建脚本

使用方法:
    $0 [选项]

选项:
    -t, --tag TAG       指定镜像标签 (默认: latest)
    -n, --name NAME     指定镜像名称 (默认: archery)
    -f, --file FILE     指定Dockerfile路径 (默认: Dockerfile)
    -c, --clean         清理构建缓存后构建
    -h, --help          显示此帮助信息

示例:
    $0                           # 构建 archery:latest
    $0 --tag v1.0.0              # 构建 archery:v1.0.0  
    $0 --name my-archery --tag dev # 构建 my-archery:dev
    $0 --clean                   # 清理缓存后构建
    
构建完成后使用:
    docker run -d -p 8888:8888 --name archery ${IMAGE_NAME}:${IMAGE_TAG}
    或
    docker-compose up -d
EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -f|--file)
            DOCKERFILE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            log_info "使用 $0 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    log_error "Docker未安装或不在PATH中"
    exit 1
fi

# 检查Dockerfile是否存在
if [[ ! -f "$DOCKERFILE" ]]; then
    log_error "Dockerfile不存在: $DOCKERFILE"
    exit 1
fi

# 检查必要的配置文件
log_info "检查构建依赖文件..."
required_files=("docker/supervisord.conf" "docker/startup.sh")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        log_error "缺少必要文件: $file"
        exit 1
    fi
done

# 显示构建信息
log_info "开始构建Docker镜像"
log_info "镜像名称: ${IMAGE_NAME}"
log_info "镜像标签: ${IMAGE_TAG}"
log_info "Dockerfile: ${DOCKERFILE}"
log_info "构建上下文: ${BUILD_CONTEXT}"

# 清理构建缓存（如果需要）
if [[ "$CLEAN_BUILD" == true ]]; then
    log_warning "清理Docker构建缓存..."
    docker builder prune -f
    log_success "缓存清理完成"
fi

# 构建镜像
log_info "正在构建镜像..."
BUILD_START_TIME=$(date +%s)

if docker build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${DOCKERFILE}" \
    --progress=plain \
    "${BUILD_CONTEXT}"; then
    
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    
    log_success "镜像构建完成！"
    log_info "构建时间: ${BUILD_DURATION} 秒"
    log_info "镜像标签: ${IMAGE_NAME}:${IMAGE_TAG}"
    
    # 显示镜像信息
    log_info "镜像详细信息:"
    docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
    
    # 显示使用提示
    echo ""
    log_success "构建成功！可以使用以下命令运行容器:"
    echo -e "${GREEN}# 单独运行:${NC}"
    echo "docker run -d -p 8888:8888 --name archery ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${GREEN}# 使用docker-compose:${NC}"
    echo "docker-compose up -d"
    echo ""
    echo -e "${GREEN}# 查看运行状态:${NC}"
    echo "docker ps"
    echo ""
    echo -e "${GREEN}# 查看日志:${NC}"
    echo "docker logs archery"
    
else
    log_error "镜像构建失败！"
    exit 1
fi 