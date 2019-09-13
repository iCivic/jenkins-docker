echo "#1. 安装nginx"
apk add nginx
which nginx

echo "#2. 替换nginx.conf 和 nginx.pid"
cat << EOF > /etc/nginx/nginx.conf
#user  nobody;
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
	
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;


	# Configuration for the server
    server {
        listen       80;
		access_log  /dev/null;   
		error_log /dev/null;
		access_log  on;   
		error_log on;
        server_name  updates.jenkins-ci.org, mirrors.jenkins-ci.org;
		
		location /download/plugins/ {
            proxy_pass  https://mirrors.tuna.tsinghua.edu.cn/jenkins/plugins/;
		}
		
		location / {
            proxy_pass  https://mirrors.tuna.tsinghua.edu.cn;
		}
    }
}

EOF

mkdir -p /run/nginx
touch /run/nginx/nginx.pid
cat << EOF >> /run/nginx/nginx.pid
11680
EOF

echo "#3. DNS 劫持域名：updates.jenkins-ci.org & mirrors.jenkins-ci.org"
cat << EOF >> /etc/hosts
127.0.0.1 updates.jenkins-ci.org
127.0.0.1 mirrors.jenkins-ci.org
EOF

echo "#4. 测试 updates.jenkins-ci.org 是否转向成功"
ping updates.jenkins-ci.org -c 5

echo "#5. 启动nginx"
kill -9 $(pidof nginx)
nginx -t
nginx
ps aux | grep nginx
