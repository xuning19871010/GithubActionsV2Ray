#!/bin/bash

# current_version: 2025-09-17 19:47:08
# 得到的节点形如：
# vless://160f2a90-9f87-4452-b27a-e4c03341c138@www.visa.com.sg:443?flow=&security=tls&encryption=none&type=ws&host=githubactions.keyso.uk&path=/githubactions&sni=githubactions.keyso.uk&fp=chrome&pbk=&sid=&serviceName=/githubactions&headerType=&mode=&seed=#xray_tunnel
# ssh登录方式
# ssh -i tmp -o "ProxyCommand=nc -x 127.0.0.1:1080 %h %p" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" root@127.0.0.1
# ssh -i xray_ssh_github_key -o "ProxyCommand=ncat --proxy-type socks5 --proxy 127.0.0.1:7005 %h %p" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" root@127.0.0.1
# ssh -i xray_ssh_github_key -o "ProxyCommand=ncat --proxy-type socks5 --proxy 127.0.0.1:9001 %h %p" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" root@127.0.0.1

# 拷贝xray_json_config_for_dig库
# scp root@43.135.118.188:/root/.ssh/id_rsa ~/.ssh; chmod 600 ~/.ssh/id_rsa; git clone -b usdt git@github.com:shoguncao/xray_json_config_for_dig.git

# 重启xray
# systemctl restart xray@bridge; systemctl restart xray@xray_ssh_github_config.service; systemctl restart xray@cloudflared_ssh_github_config.service

sudo apt-get update
sudo apt-get install openssh-server
# sudo apt-get install proxychains

# 创建日志目录
mkdir -p logs

sudo perl -pi -e "s/socks4.*127\.0\.0\.1.*9050/socks5 127.0.0.1 10801/g" /etc/proxychains.conf

sudo perl -pi -e "s/(^.*)(PubkeyAuthentication)(.*$)/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sudo perl -pi -e "s/(^.*)(AuthorizedKeysFile)(.*$)/AuthorizedKeysFile .ssh\/authorized_keys/g" /etc/ssh/sshd_config
sudo perl -pi -e "s/(^.*)(ClientAliveInterval)(.*$)/ClientAliveInterval 3600/g" /etc/ssh/sshd_config
sudo perl -pi -e "s/(^.*)(ClientAliveCountMax)(.*$)/ClientAliveCountMax 0/g" /etc/ssh/sshd_config
sudo perl -pi -e "s/(^.*)(TCPKeepAlive)(.*$)/TCPKeepAlive yes/g" /etc/ssh/sshd_config
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXzkIENwv67cMTwIiMr+sMKpkuuWb5wYhdv79R5lqOhtBE71F92XN7Wt/59mJMve+agx82w9Til3bBwkhPOtf3pup+NvDdhXKtq4ljrmxq9T88QM0KBYvFnglIGQ8v+Y+Q4h4/pj6DyoOiUJEQK0b9PxP4SfyoTq6hp8RreGJ5TFOhwgyRt6E+TuTuLdCRd7DMnEpzJNyzAAdxAo4G9TROgycEJcZ5uX2Jex0fGTnJJ9pJtlOUrHr0W991sHS1Lm37uGQB8pqZXa2WftqZIt0bjFYAqS7EV5Nx4NJdCV3dC6Bu01I3iJyBkubxD1/tTe6Ueok4iAXR5tkb4zZ5V+WNv12/2wxXbYmElJD4Jrydv7qMuY4cgnNgAI58kuMcvBWBTA6QtEOyRiNUThz5BO9GvvzAQivlawaiuoYQC2OwwGQ+3WEso496nzNXlp7wO/NemNyZopzsYhQX7w4DYVk6lADdHUIZ+di1sU3mbQthyJ7RHHO8YmQFRqe/2DRqmAyDDH+SbzCtijFEoElEFgEA2PDRvmwJLdBzQf5uzMMIW09PfzkxQuCJAI8eSHepP22zSrq7BYqPqVEC68Pc5/uyuBEF0a4aQUaBSv/CcDkNHNQL3unbI4X7D6HkRRxLWdcYIgH6kgdxHTHUhSD+lVOqq6g1ISKrKxLP+kqF0uMJiQ== xray_ssh_github_key.gmail.com" | sudo tee -a /root/.ssh/authorized_keys
sudo service ssh start

echo "cat /etc/ssh/sshd_config"
cat /etc/ssh/sshd_config

mkdir -p xray
pushd xray
wget https://github.com/XTLS/Xray-core/releases/download/v24.12.31/Xray-linux-64.zip
unzip Xray-linux-64.zip
sudo nohup ./xray run -config ../xray.json > /dev/null &
sudo nohup ./xray run -config ../bridge_guest.json > /dev/null &
popd

# 设置nginx_seq默认值为0
nginx_seq=${nginx_seq:-0}
echo "nginx_seq: $nginx_seq"

# 设置cloudflared_token默认值
cloudflared_token=${cloudflared_token:-"eyJhIjoiNGM3MzkzMWQ4YTQ2NjNlNTBhZDVlYmNmMWI4ZGJiOTUiLCJ0IjoiZTgxMmIzZmUtZjVhOS00NmUxLWI2NzUtNWEyZGRhY2E5ZTQ4IiwicyI6Ik9XRTFNekV3WVRVdE1EQmhNUzAwWmpKbExXSXhOak10TlRJMk16aGtaVE5sWVRKaSJ9"}
echo "cloudflared_token: ${cloudflared_token:0:20}..." # 只打印前20个字符

# 动态修改nginx.conf，添加location /nginx_seq
sed -i "/location \/articles {/i\\
        location \/nginx_seq {\\
            return 200 \"$nginx_seq\";\\
            add_header Content-Type text/plain;\\
        }" cloudflared/nginx.conf

# 运行cloudflared
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install cloudflared
sudo cloudflared service install $cloudflared_token

# 运行nginx
sudo lsof -i :7004 | awk 'NR>1 {print $2}' | xargs sudo kill -9
pushd cloudflared
sudo nginx -c $(pwd)/nginx.conf
popd

# 运行FRP客户端
echo "Starting FRP client..."
pushd frp
[ ! -f "frpc" ] && tar -xzf frp_0.67.0_linux_amd64.tar.gz --strip-components=1 && chmod +x frpc
sudo nohup ./frpc -c frpc.toml > ../logs/frpc.log 2>&1 &
echo "FRP client started, log: logs/frpc.log"
popd

# vless://160f2a90-9f87-4452-b27a-e4c03341c138@cloudflared.keyso.uk:443?security=tls&encryption=none&type=ws&host=cloudflared.keyso.uk&path=/articles&sni=cloudflared.keyso.uk&fp=chrome#cloudflared.keyso.uk
pushd xray
sudo ./xray run -config ../cloudflared/xray.server.config.json > /dev/null
popd 

exit 0
