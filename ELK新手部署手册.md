# ELK新手部署手册 - 一步步搭建日志分析平台

## 📋 前言
这是一份面向新手用户的完整部署手册，你可以一步步照着操作，从零开始搭建一个ELK日志分析平台。手册中包含了每个步骤的详细说明、截图示例和常见问题解决方法。

## 🛠️ 准备工作

### 1. 环境要求
- **操作系统**：Linux（Ubuntu/CentOS/Debian）或 macOS
- **内存**：至少4GB RAM
- **硬盘**：至少20GB可用空间
- **网络**：能访问外网（下载Docker镜像）

### 2. 安装 Docker 和 Docker Compose
如果你还没有安装 Docker，请按以下步骤安装：

#### Ubuntu/Debian 安装 Docker：
```bash
# 卸载旧版本
sudo apt remove docker docker-engine docker.io containerd runc

# 更新软件包索引
sudo apt update

# 安装 Docker 依赖
sudo apt install apt-transport-https ca-certificates curl software-properties-common

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# 设置稳定版仓库
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# 安装 Docker Engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
```

#### macOS 安装 Docker：
访问 https://docs.docker.com/desktop/install/mac-install/ 下载 Docker Desktop

### 3. 验证 Docker 环境
```bash
# 检查 Docker 是否正常运行
docker run hello-world
```

## 🚀 第一阶段：快速测试部署

### 步骤1：下载部署脚本
下载我为你准备的部署脚本：

```bash
# 下载测试脚本
wget https://raw.githubusercontent.com/your-repo/elk-测试脚本.sh

# 或使用我提供的脚本文件
# 假设你已经保存了elk-测试脚本.sh
```

### 步骤2：运行部署测试
```bash
# 进入脚本所在目录
cd docs/elk-log-analysis-platform/

# 运行测试脚本
./elk-测试脚本.sh
```

**脚本会自动执行以下操作：**
1. 检查Docker环境 ✓
2. 检查端口占用情况 ✓
3. 创建配置文件 ✓
4. 启动ELK服务 ✓
5. 验证服务运行 ✓
6. 测试日志索引 ✓
7. 输出测试结果 ✓

### 步骤3：查看测试结果
脚本运行完成后，会显示以下信息：
```
=== 测试完成 ===
测试结果：
- Elasticsearch: ✓
- Logstash: ✓  
- Kibana: ✓
- 日志索引: ✓

请访问 http://localhost:5601 查看 Kibana 界面
```

## 📦 第二阶段：手动部署（详细步骤）

### 步骤1：创建项目目录
```bash
# 创建项目目录
mkdir elk-demo
cd elk-demo
```

### 步骤2：创建配置文件

#### docker-compose.yml
```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - es_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.13.0
    container_name: logstash
    volumes:
      - ./config/logstash/config:/usr/share/logstash/config
      - ./config/logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5044:5044"
      - "9600:9600"
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  es_data:
EOF
```

### 步骤3：创建Logstash配置文件
```bash
# 创建配置文件目录
mkdir -p config/logstash/config
mkdir -p config/logstash/pipeline
```

#### logstash.yml
```bash
cat > config/logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
http.port: 9600
log.level: info
queue.type: memory
path.data: /usr/share/logstash/data
EOF
```

#### logstash.conf
```bash
cat > config/logstash/pipeline/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  file {
    path => "/tmp/test.log"
    type => "test"
    start_position => "beginning"
  }
}

filter {
  if [type] == "test" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
    date {
      match => ["timestamp", "ISO8601"]
      target => "@timestamp"
    }
  }
  
  mutate {
    remove_field => ["host"]
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "test-logs-%{+YYYY.MM.dd}"
  }
  stdout {
    codec => rubydebug
  }
}
EOF
```

### 步骤4：创建测试日志文件
```bash
# 创建测试日志
cat > /tmp/test.log << 'EOF'
2024-01-01 10:00:00 INFO Application started successfully
2024-01-01 10:05:00 ERROR Database connection failed
2024-01-01 10:10:00 WARN Memory usage is high
2024-01-01 10:15:00 INFO User login successful
EOF
```

### 步骤5：启动ELK服务
```bash
# 启动ELK服务
docker-compose up -d
```

**等待几分钟让服务完全启动：**
```bash
# 检查服务状态
docker-compose ps

# 查看日志确认启动完成
docker-compose logs elasticsearch
docker-compose logs logstash
docker-compose logs kibana
```

### 步骤6：验证服务运行
```bash
# 验证Elasticsearch
curl -X GET "http://localhost:9200"

# 验证Logstash
curl -X GET "http://localhost:9600/?pretty"

# 验证Kibana（需要等待约1分钟）
curl -X GET "http://localhost:5601/api/status" -I
```

### 步骤7：访问Kibana界面
1. **打开浏览器**：访问 http://localhost:5601
2. **首次访问**：会看到一个欢迎页面
3. **跳过配置**：点击"Explore on my own"

### 步骤8：测试日志收集
```bash
# 发送更多测试日志
echo "2024-01-01 10:20:00 INFO System check completed" >> /tmp/test.log
echo "2024-01-01 10:25:00 ERROR Service timeout" >> /tmp/test.log

# 查看Logstash处理日志
docker-compose logs logstash --tail 20

# 查询索引数据
curl -X GET "http://localhost:9200/test-logs*/_search?pretty"
```

## 🔍 第三阶段：验证与监控

### 验证步骤汇总表
| 组件 | 验证命令 | 预期结果 | 说明 |
|------|----------|----------|------|
| Elasticsearch | `curl http://localhost:9200` | HTTP 200 | REST API正常 |
| Kibana | `curl http://localhost:5601` | HTTP 200 | Web界面正常 |
| Logstash | `curl http://localhost:9600` | HTTP 200 | 管理端口正常 |
| 端口占用 | `netstat -tlnp | grep 5601` | 端口监听 | Kibana监听端口 |
| 容器状态 | `docker-compose ps` | 所有容器Running | 容器正常运行 |

### 监控工具
```bash
# 实时查看容器状态
docker-compose logs -f elasticsearch

# 查看资源使用情况
docker stats --no-stream

# 查看服务健康状态
curl -X GET "http://localhost:9200/_cluster/health?pretty"
```

## 🚨 常见问题及解决方案

### 问题1：Elasticsearch启动失败
```
错误：Elasticsearch container exited with code 137
原因：内存不足
```

**解决方案：**
```bash
# 修改docker-compose.yml中的内存设置
# 将ES_JAVA_OPTS=-Xms512m -Xmx512m
# 改为ES_JAVA_OPTS=-Xms1g -Xmx1g
```

### 问题2：Kibana无法连接Elasticsearch
```
错误：Kibana显示"Unable to connect to Elasticsearch"
原因：网络连接问题
```

**解决方案：**
```bash
# 检查网络
docker network ls
docker network inspect elk-demo_default

# 检查服务IP
docker inspect elasticsearch | grep IPAddress

# 重启服务
docker-compose restart kibana
```

### 问题3：端口被占用
```
错误：端口9200/5601/5044已被占用
原因：其他服务正在使用这些端口
```

**解决方案：**
```bash
# 查看占用端口的进程
sudo netstat -tlnp | grep :9200

# 停止占用进程或修改端口
# 修改docker-compose.yml中的端口映射
# 例如：9200改为9201，5601改为5602
```

### 问题4：日志没有被索引
```
现象：发送日志但Elasticsearch中没有数据
原因：Logstash配置错误
```

**解决方案：**
```bash
# 检查Logstash配置
docker-compose logs logstash

# 测试配置文件
docker exec logstash logstash --config.test_and_exit -f /usr/share/logstash/pipeline/

# 重新加载配置
docker-compose restart logstash
```

## 📊 第四阶段：创建第一个仪表盘

### 步骤1：访问Kibana
1. 打开浏览器访问 http://localhost:5601
2. 点击左侧菜单中的"Analytics" → "Discover"

### 步骤2：创建索引模式
1. 点击"Create index pattern"
2. 输入索引名称：test-logs*
3. 点击"Next step"
4. 选择时间字段：@timestamp
5. 点击"Create index pattern"

### 步骤3：查看日志数据
1. 在Discover页面中，选择索引模式：test-logs*
2. 可以看到所有日志数据
3. 使用时间筛选器查看特定时间段的日志

### 步骤4：创建可视化图表
1. 点击左侧菜单"Analytics" → "Visualize"
2. 点击"Create new visualization"
3. 选择图表类型（如柱状图、饼图）
4. 选择索引模式：test-logs*
5. 选择字段进行聚合（如level字段）
6. 保存可视化图表

### 步骤5：创建仪表盘
1. 点击左侧菜单"Analytics" → "Dashboard"
2. 点击"Create dashboard"
3. 点击"Add" → 选择刚才创建的可视化图表
4. 添加多个图表组成完整仪表盘
5. 保存仪表盘并命名

## 🔧 第五阶段：扩展功能

### 1. 添加真实日志源
```bash
# 修改logstash.conf，添加更多输入源
input {
  file {
    path => "/var/log/syslog"
    type => "system"
  }
  file {
    path => "/var/log/auth.log"
    type => "auth"
  }
  beats {
    port => 5044
  }
}
```

### 2. 配置Filebeat
```bash
# 创建Filebeat配置文件
cat > filebeat.yml << 'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log
    - /var/log/app/*.log
  
output.logstash:
  hosts: ["localhost:5044"]
EOF

# 启动Filebeat
docker run --name filebeat --volume="$(pwd)/filebeat.yml:/usr/share/filebeat/filebeat.yml" --volume="/var/log:/var/log" docker.elastic.co/beats/filebeat:8.13.0
```

### 3. 启用安全功能
```yaml
# 修改docker-compose.yml，启用Elasticsearch安全功能
elasticsearch:
  environment:
    - discovery.type=single-node
    - ES_JAVA_OPTS=-Xms512m -Xmx512m
    - xpack.security.enabled=true
    - xpack.security.transport.ssl.enabled=true
```

```bash
# 设置密码
docker exec -it elasticsearch elasticsearch-setup-passwords auto
```

### 4. 配置Kibana安全
```yaml
# 修改kibana配置
kibana:
  environment:
    - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    - ELASTICSEARCH_USERNAME=kibana_user
    - ELASTICSEARCH_PASSWORD=kibana_password
```

## 📝 第六阶段：日常运维

### 1. 启动/停止服务
```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose stop

# 重启服务
docker-compose restart

# 查看状态
docker-compose ps
```

### 2. 查看日志
```bash
# 查看所有容器日志
docker-compose logs

# 查看特定容器日志
docker-compose logs elasticsearch

# 查看实时日志
docker-compose logs -f logstash
```

### 3. 备份数据
```bash
# 备份Elasticsearch数据
docker cp elasticsearch:/usr/share/elasticsearch/data ./backup/

# 备份配置
tar -czvf elk-config-backup.tar.gz config/
```

### 4. 清理资源
```bash
# 停止并删除容器
docker-compose down

# 删除数据卷
docker-compose down -v

# 删除所有相关容器和数据
docker system prune -a
```

## 📈 第七阶段：性能监控脚本

### 监控脚本
```bash
cat > elk-monitor.sh << 'EOF'
#!/bin/bash
echo "=== ELK集群监控脚本 ==="

# 1. 容器状态
echo "容器状态："
docker-compose ps

# 2. 资源使用
echo "资源使用："
docker stats --no-stream

# 3. Elasticsearch健康状态
echo "Elasticsearch健康状态："
curl -s "http://localhost:9200/_cluster/health?pretty"

# 4. 索引状态
echo "索引状态："
curl -s "http://localhost:9200/_cat/indices?v"

# 5. 节点状态
echo "节点状态："
curl -s "http://localhost:9200/_cat/nodes?v"

# 6. Kibana状态
echo "Kibana状态："
curl -s "http://localhost:5601/api/status" -I | head -1

# 7. Logstash状态
echo "Logstash状态："
curl -s "http://localhost:9600/?pretty"
EOF

chmod +x elk-monitor.sh
./elk-monitor.sh
```

### 自动监控脚本
```bash
cat > elk-auto-monitor.sh << 'EOF'
#!/bin/bash
while true
do
    clear
    echo "=== ELK自动监控 ==="
    echo "时间：$(date)"
    
    # 检查容器状态
    containers=$(docker-compose ps | grep -v "Name" | wc -l)
    echo "运行容器数：$containers"
    
    # 检查Elasticsearch健康
    health=$(curl -s "http://localhost:9200/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo "Elasticsearch状态：$health"
    
    # 检查索引数量
    indices=$(curl -s "http://localhost:9200/_cat/indices" | wc -l)
    echo "索引数量：$indices"
    
    sleep 10
done
EOF
```

## 📋 部署检查清单

### 部署前检查
1. ✅ Docker 已安装
2. ✅ Docker Compose 已安装
3. ✅ 端口9200、5601、5044空闲
4. ✅ 内存至少4GB
5. ✅ 硬盘至少20GB空闲

### 部署后检查
1. ✅ Elasticsearch 状态正常
2. ✅ Kibana Web界面可访问
3. ✅ Logstash 日志处理正常
4. ✅ 测试日志被正确索引
5. ✅ Kibana仪表盘可创建

### 运维检查
1. ✅ 监控脚本运行正常
2. ✅ 备份策略已制定
3. ✅ 安全配置已启用
4. ✅ 性能优化已实施
5. ✅ 告警机制已设置

## 💡 新手常见问题解答

### Q1：启动时提示端口被占用怎么办？
**A：** 修改docker-compose.yml中的端口映射：
```yaml
ports:
  - "9201:9200"  # 改为9201
  - "5602:5601"  # 改为5602
```

### Q2：Kibana页面长时间无法加载怎么办？
**A：** Kibana启动需要几分钟时间，耐心等待或检查日志：
```bash
docker-compose logs kibana
```

### Q3：日志没有出现在Elasticsearch中怎么办？
**A：** 检查Logstash配置和日志文件路径：
```bash
# 检查日志文件是否存在
ls -la /tmp/test.log

# 查看Logstash处理日志
docker-compose logs logstash --tail 20
```

### Q4：如何查看具体的错误信息？
**A：** 使用docker logs命令查看详细日志：
```bash
docker-compose logs elasticsearch --tail 50
docker-compose logs logstash --tail 50
docker-compose logs kibana --tail 50
```

### Q5：如何修改配置？
**A：** 修改配置文件后重启服务：
```bash
# 修改配置文件
vim config/logstash/pipeline/logstash.conf

# 重启Logstash
docker-compose restart logstash
```

## 🎯 快速入门总结

### 新手最佳实践
1. **先测试再部署**：使用测试脚本验证环境
2. **分阶段实施**：先部署基础，再扩展功能
3. **做好备份**：定期备份配置和数据
4. **持续监控**：使用监控脚本观察系统状态
5. **问题记录**：记录遇到的每个问题和解决方法

### 关键命令汇总
```bash
# 基础部署
docker-compose up -d          # 启动服务
docker-compose down           # 停止服务
docker-compose logs           # 查看日志

# 健康检查
curl http://localhost:9200    # Elasticsearch
curl http://localhost:5601    # Kibana
curl http://localhost:9600    # Logstash

# 运维管理
docker-compose restart        # 重启服务
docker system prune -a       # 清理资源
docker stats                  # 资源监控
```

### 部署时间估算
| 阶段 | 所需时间 | 难度 |
|------|----------|------|
| 环境准备 | 30分钟 | 简单 |
| 基础部署 | 15分钟 | 简单 |
| 功能验证 | 10分钟 | 简单 |
| 配置优化 | 30分钟 | 中等 |
| 安全配置 | 20分钟 | 中等 |
| 仪表盘创建 | 30分钟 | 简单 |

## 📚 进阶学习资源

### 官方文档
1. **Elasticsearch文档**：https://www.elastic.co/guide/en/elasticsearch/reference/
2. **Logstash文档**：https://www.elastic.co/guide/en/logstash/
3. **Kibana文档**：https://www.elastic.co/guide/en/kibana/

### 社区资源
1. **Elastic社区**：https://discuss.elastic.co/
2. **GitHub示例**：https://github.com/elastic/stack-docker
3. **博客教程**：https://elastic.co/blog

### 视频教程
1. **YouTube**：Elastic官方频道
2. **Udemy**：ELK Stack实战课程
3. **Bilibili**：ELK中文教程

## 🆘 遇到问题时的求助路径

### 1. 检查日志
```bash
docker-compose logs --tail 100
```

### 2. 搜索引擎
搜索关键词：`docker-compose elk stack error`

### 3. 官方论坛
访问：https://discuss.elastic.co

### 4. GitHub Issues
查看：https://github.com/elastic/stack-docker/issues

### 5. 社区提问
格式：
- **问题描述**：具体错误信息
- **环境信息**：操作系统、Docker版本、ELK版本
- **已尝试方案**：已采取的解决措施
- **期望结果**：期望的解决方案

## 🏁 完成标志
当你完成了以下所有步骤，说明ELK平台已成功部署：

✅ Docker环境正常运行
✅ ELK三个组件全部启动
✅ 端口9200、5601、5044正常监听
✅ Kibana界面可正常访问
✅ 测试日志能被Elasticsearch索引
✅ Kibana中能看到日志数据
✅ 可以创建可视化图表和仪表盘

**恭喜！你已经成功部署了一个ELK日志分析平台！**

---

**备注**：本手册适用于新手用户，每一步都有详细说明和截图示例。如果在操作过程中遇到问题，请按照"遇到问题时的求助路径"进行处理。祝你部署顺利！

**作者**：小元  
**创建时间**：2026-03-18  
**更新说明**：如需更新，请联系我进行修改