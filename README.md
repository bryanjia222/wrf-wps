# WRF + WPS Docker Container

这个Docker容器包含了完整的WRF (Weather Research and Forecasting) 模型和WPS (WRF Pre-Processing System) 环境。

## 项目结构

```
wrf-docker/
├── Dockerfile              # Docker镜像定义
├── docker-compose.yml      # Docker Compose配置
├── .dockerignore          # Docker忽略文件
├── Makefile              # 便捷操作命令
├── setup.sh              # 初始设置脚本
├── README.md             # 本文档
├── scripts/              # 运行脚本
│   ├── wrf_info.sh      # WRF信息脚本
│   └── run.sh           # 运行辅助脚本
├── config/               # 配置文件
│   ├── namelist.wps     # WPS配置
│   └── namelist.input   # WRF配置
├── WPS_GEOG/            # 地理数据（需下载）
├── data/                # 数据目录
│   ├── input/           # 输入数据
│   └── output/          # 输出数据
└── logs/                # 日志文件
```

## 系统要求

- Docker Engine 20.10+
- Docker Compose 1.29+
- 至少8GB RAM（推荐16GB+）
- 至少20GB可用磁盘空间
- Linux/macOS系统（Windows需要WSL2）

## 快速开始

### 1. 克隆或创建项目

```bash
# 创建项目目录
mkdir wrf-docker && cd wrf-docker

# 将所有文件放入相应目录
# - Dockerfile 放在根目录
# - 脚本文件放入 scripts/
# - 配置文件放入 config/
```

### 2. 初始设置

```bash
# 使用setup脚本
chmod +x setup.sh
./setup.sh

# 或使用Makefile
make setup
```

### 3. 构建和运行

```bash
# 构建Docker镜像
make build

# 启动容器
make up

# 查看容器状态
make status
```

### 4. 访问容器

```bash
# 进入容器shell
make shell

# 或直接使用docker-compose
docker compose exec wrf-wps bash
```

## 使用指南

### 准备输入数据

1. **GFS数据**
```bash
# 下载GFS数据到 data/input/
cd data/input
wget https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDD/HH/atmos/gfs.tCCz.pgrb2.0p25.fFFF
```

2. **ERA5数据**
- 从ECMWF网站下载
- 放置到 data/input/ 目录

### 运行WPS

1. **修改配置**
```bash
# 编辑 config/namelist.wps
vim config/namelist.wps
```

2. **复制配置到容器**
```bash
make copy-namelist
```

3. **运行WPS流程**
```bash
# 运行完整WPS流程
make wps

# 或分步运行
make geogrid
make ungrib
make metgrid
```

### 运行WRF

1. **修改配置**
```bash
# 编辑 config/namelist.input
vim config/namelist.input
```

2. **运行real.exe**
```bash
make real
```

3. **运行WRF模拟**
```bash
# 默认使用4个处理器
make wrf

# 或在容器内指定处理器数
docker compose exec wrf-wps run.sh wrf 8
```

### 监控和调试

```bash
# 查看容器日志
make logs

# 查看WRF输出
make tail-wrf

# 检查错误
make check-errors

# 列出输出文件
make list-output
```

## Makefile命令参考

| 命令 | 说明 |
|------|------|
| `make help` | 显示帮助信息 |
| `make setup` | 初始设置 |
| `make build` | 构建Docker镜像 |
| `make up` | 启动容器 |
| `make down` | 停止容器 |
| `make restart` | 重启容器 |
| `make shell` | 进入容器shell |
| `make logs` | 查看容器日志 |
| `make clean` | 清理容器和镜像 |
| `make wps` | 运行WPS |
| `make wrf` | 运行WRF |
| `make info` | 显示WRF/WPS信息 |
| `make status` | 查看容器状态 |

## 高级配置

### 修改WRF版本

编辑Dockerfile中的版本变量：
```dockerfile
ENV WRF_VERSION=4.5.1
ENV WPS_VERSION=4.5
```

### 调整资源限制

编辑docker-compose.yml：
```yaml
deploy:
  resources:
    limits:
      cpus: '8'      # 增加CPU核心
      memory: 16G    # 增加内存
```

### 使用高分辨率地理数据

```bash
cd WPS_GEOG
# 下载高分辨率数据（~50GB）
wget https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
tar -xzf geog_high_res_mandatory.tar.gz
```

## 故障排除

### 1. 编译失败
- 检查Docker日志：`docker compose logs`
- 确保有足够的内存（至少4GB用于编译）

### 2. WPS运行错误
- 检查geogrid.log, ungrib.log, metgrid.log
- 验证地理数据路径是否正确
- 确认输入数据格式

### 3. WRF运行错误
- 检查rsl.error.* 和 rsl.out.* 文件
- 验证namelist.input时间设置
- 确保met_em文件正确

### 4. 内存不足
- 减小模拟域大小
- 减少垂直层数
- 增加Docker内存限制

## 最佳实践

1. **数据管理**
   - 定期清理output目录
   - 使用符号链接管理大型数据集
   - 备份重要的namelist文件

2. **性能优化**
   - 根据CPU核心数调整并行进程
   - 使用本地SSD存储提高I/O性能
   - 适当设置OpenMP线程数

3. **版本控制**
   - 将namelist文件纳入版本控制
   - 记录每次运行的配置参数
   - 保存成功运行的配置模板

## 参考资源

- [WRF官方文档](https://www2.mmm.ucar.edu/wrf/users/)
- [WRF用户指南](https://www2.mmm.ucar.edu/wrf/users/docs/user_guide_v4/)
- [WPS用户指南](https://www2.mmm.ucar.edu/wrf/users/docs/user_guide_v4/v4.5/users_guide_chap3.html)
- [WRF论坛](https://forum.mmm.ucar.edu/)