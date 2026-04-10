#!/bin/bash

# ELK 平台测试脚本
# 用于快速测试 ELK 平台的基本功能

echo "=== ELK 平台测试脚本 ==="

# 1. 检查环境
echo "1. 检查 Docker 环境"
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    exit 1
fi

echo "✓ Docker 环境正常"

# 2. 检查端口占用
echo "2. 检查端口占用情况"
ports=(9200 5601 5044)

for port in ${ports[@]}; do
    if netstat -tlnp | grep ":$port"; then
        echo "警告: 端口 $port 已被占用"
    else
        echo "✓ 端口 $port 可用"
    fi
done

# 3. 下载配置文件
echo "3. 下载配置文件"
mkdir -p config/logstash/config
mkdir -p config/logstash/pipeline

# 创建 docker-compose.yml
echo "创建 docker-compose.yml..."
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
    ulimits:
      memlock:
        soft: -1
        hard: -1

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

# 创建 Logstash 配置文件
echo "创建 logstash.yml..."
cat > config/logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
http.port: 9600
log.level: info
queue.type: memory
path.data: /usr/share/logstash/data
EOF

echo "创建 logstash.conf..."
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

# 4. 创建测试日志文件
echo "4. 创建测试日志文件"
cat > /tmp/test.log << 'EOF'
2024-01-01 10:00:00 INFO Application started successfully
2024-01-01 10:05:00 ERROR Database connection failed
2024-01-01 10:10:00 WARN Memory usage is high
2024-01-01 10:15:00 INFO User login successful
EOF

# 5. 启动 ELK 服务
echo "5. 启动 ELK 服务"
docker-compose up -d

echo "等待服务启动（30秒）..."
sleep 30

# 6. 验证服务
echo "6. 验证 ELK 服务"

# 检查 Elasticsearch
echo "检查 Elasticsearch..."
es_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200)
if [ "$es_status" == "200" ]; then
    echo "✓ Elasticsearch 运行正常"
else
    echo "✗ Elasticsearch 连接失败"
fi

# 检查 Logstash
echo "检查 Logstash..."
ls_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9600)
if [ "$ls_status" == "200" ]; then
    echo "✓ Logstash 运行正常"
else
    echo "✗ Logstash 连接失败"
fi

# 检查 Kibana
echo "检查 Kibana..."
kb_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5601)
if [ "$kb_status" == "200" ]; then
    echo "✓ Kibana 运行正常"
else
    echo "✗ Kibana 连接失败"
fi

# 7. 测试日志索引
echo "7. 测试日志索引"
# 发送测试日志
echo "发送测试日志到 Logstash..."
cat /tmp/test.log | while read line; do
    echo "$line" >> /tmp/test.log
done

echo "等待日志处理（10秒）..."
sleep 10

# 检查索引
echo "检查索引状态..."
curl -s "http://localhost:9200/_cat/indices?v" | grep test-logs

# 8. 查询测试日志
echo "8. 查询测试日志"
curl -X GET "http://localhost:9200/test-logs-*/_search?pretty" -H 'Content-Type: application/json' \
  -d'
{
  "query": {
    "match_all": {}
  },
  "size": 10
}
'

# 9. 清理和总结
echo "9. 清理测试环境"
echo "停止 ELK 服务..."
docker-compose down

echo "删除测试文件..."
rm -f /tmp/test.log

echo "=== 测试完成 ==="
echo "测试结果："
echo "- Elasticsearch: $(if [ "$es_status" == "200" ]; then echo '✓'; else echo '✗'; fi)"
echo "- Logstash: $(if [ "$ls_status" == "200" ]; then echo '✓'; else echo '✗'; fi)"
echo "- Kibana: $(if [ "$kb_status" == "200" ]; then echo '✓'; else echo '✗'; fi)"
echo "- 日志索引: $(curl -s "http://localhost:9200/_cat/indices?v" | grep test-logs > /dev/null && echo '✓' || echo '✗')"

echo "请访问 http://localhost:5601 查看 Kibana 界面"