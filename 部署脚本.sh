#!/bin/bash

# ELK部署脚本
# 创建时间：2026年4月10日 22:54:36 CST
# 作者：小元

echo "=============================================="
echo "ELK日志分析平台部署脚本"
echo "=============================================="
echo "当前时间：$(date)"
echo ""

# 检查环境
echo "1. 检查环境..."
echo ""

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    exit 1
else
    echo "✅ Docker已安装：$(docker --version)"
fi

# 检查Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
else
    echo "✅ Docker Compose已安装"
fi

# 检查端口
echo "2. 检查端口占用情况..."
ports=(9200 5601 5044)

for port in ${ports[@]}; do
    if netstat -tlnp | grep ":$port"; then
        echo "⚠️ 端口 $port 已被占用，请修改docker-compose.yml中的端口映射"
    else
        echo "✅ 端口 $port 可用"
    fi
done

echo ""
echo "3. 创建项目目录..."
mkdir -p elk-demo
cd elk-demo
echo "✅ 项目目录创建成功"

echo ""
echo "4. 创建docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.0
    container_name: elastic1
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
    container_name: logstash1
    volumes:
      - ./config/logstash/config:/usr/share/logstash/config
      - ./config/logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5044:5044"
      - "9600:9600"
    depends_on:
      - elastic1

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.0
    container_name: kibana1
    environment:
      - ELASTICSEARCH_HOSTS=http://elastic1:9200
    ports:
      - "5601:5601"
    depends_on:
      - elastic1

volumes:
  es_data:
EOF
echo "✅ docker-compose.yml创建成功"

echo ""
echo "5. 创建Logstash配置目录..."
mkdir -p config/logstash/config
mkdir -p config/logstash/pipeline
echo "✅ 配置目录创建成功"

echo ""
echo "6. 创建logstash.yml..."
cat > config/logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
http.port: 9600
log.level: info
queue.type: memory
path.data: /usr/share/logstash/data
EOF
echo "✅ logstash.yml创建成功"

echo ""
echo "7. 创建logstash.conf..."
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
    hosts => ["http://elastic1:9200"]
    index => "test-logs-%{+YYYY.MM.dd}"
  }
  stdout {
    codec => rubydebug
  }
}
EOF
echo "✅ logstash.conf创建成功"

echo ""
echo "8. 创建测试日志文件..."
cat > /tmp/test.log << 'EOF'
2024-01-01 10:00:00 INFO Application started successfully
2024-01-01 10:05:00 ERROR Database connection failed
2024-01-01 10:10:00 WARN Memory usage is high
2024-01-01 10:15:00 INFO User login successful
EOF
echo "✅ 测试日志文件创建成功"

echo ""
echo "9. 启动ELK服务..."
docker-compose up -d
echo "✅ 服务启动完成"

echo ""
echo "10. 等待服务启动（60秒）..."
sleep 60

echo ""
echo "11. 验证服务状态..."
echo ""

# 验证Elasticsearch
if curl -s "http://localhost:9200" > /dev/null; then
    echo "✅ Elasticsearch运行正常"
else
    echo "❌ Elasticsearch连接失败"
fi

# 验证Logstash
if curl -s "http://localhost:9600/?pretty" > /dev/null; then
    echo "✅ Logstash运行正常"
else
    echo "❌ Logstash连接失败"
fi

# 验证Kibana
if curl -s "http://localhost:5601/api/status" -I | grep "200" > /dev/null; then
    echo "✅ Kibana运行正常"
else
    echo "❌ Kibana连接失败"
fi

echo ""
echo "12. 查看容器状态..."
docker-compose ps

echo ""
echo "13. 发送测试日志..."
echo "2024-01-01 10:20:00 INFO System check completed" >> /tmp/test.log
echo "2024-01-01 10:25:00 ERROR Service timeout" >> /tmp/test.log
echo "✅ 测试日志发送完成"

echo ""
echo "14. 查询索引数据..."
curl -s -X GET "http://localhost:9200/test-logs*/_search?pretty" | grep -q "total" && echo "✅ 日志已被索引" || echo "❌ 日志未索引成功"

echo ""
echo "=============================================="
echo "部署完成！"
echo "=============================================="
echo ""
echo "访问地址："
echo "- Kibana: http://localhost:5601"
echo "- Elasticsearch: http://localhost:9200"
echo "- Logstash: http://localhost:9600"
echo ""
echo "下一步操作："
echo "1. 打开浏览器访问 http://localhost:5601"
echo "2. 点击左侧菜单中的'Analytics' → 'Discover'"
echo "3. 创建索引模式 'test-logs*'"
echo "4. 查看日志数据并创建仪表盘"
echo ""
echo "常用命令："
echo "- 查看日志：docker-compose logs"
echo "- 重启服务：docker-compose restart"
echo "- 停止服务：docker-compose stop"
echo "- 清理资源：docker-compose down"
echo ""
echo "如有问题，请参考部署手册中的常见问题解决方案。"