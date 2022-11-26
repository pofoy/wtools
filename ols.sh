#!/bin/bash
########################
###  QQ群 946154621  ###
########################
clear && cd ~
repo_raw=https://raw.githubusercontent.com/mina998/wtools/lsws
ols_root=/usr/local/lsws
vhs_root=/www
user=nobody
group=nogroup
doc_folder=public_html
ols=~/.ols
mysql_root_pass=
lsws_cfg=$ols_root/conf/httpd_config.conf
cf_vhs_root=$ols_root/conf/vhosts
os_name=$(cat /etc/os-release | grep ^ID= | cut -d = -f 2)
if [ -f /etc/lsb-release ]; then
    os_version=$(cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -d = -f 2)
else
    os_version=$(cat /etc/os-release | grep VERSION= | sed -r 's/VERSION=".*\(([a-z]+)\)"/\1/')
fi
RC="\033[38;5;196m"; RR="\033[31m"; GC="\033[38;5;82m"; LG="\033[38;5;72m"; BC="\033[39;1;34m"; SB="\033[38;5;45m"
CC="\033[38;5;208m"; PC="\033[38;5;201m"; YC="\033[38;5;148m"; ED="\033[0m";
function error_msg {
    clear
    echo -e "\n$RC${1}$ED\n"
}
[ $(id -u) -gt 0 ] && error_msg "请以root身份运行." && exit 0
function echoGC {
    echo -e "$GC${1}$ED"
}
function echoLG {
    echo -e "$LG${1}$ED"
}
function echoCC {
    echo -e "$CC${1}$ED"
}
function echoYC {
    echo -e "$YC${1}$ED"
}
function echoRR {
    echo -e "$RR${1}$ED"
}
function input {
    local msg="$1"
    echo -ne "$BC${msg}$ED "
}
function confirm {
    local msg="$1"
    echo -ne "$SB${msg}$ED "
} 
function random_str {
    local length=10
    [ -n "$1" ] && length=$1
    echo $(tr -dc 'a-z' < /dev/urandom | head -c $length)
}
function fetch_file {
    local file=~/.temp.o; local url=$repo_raw/$1
    [[ $1 =~ ^https*://.* ]] && url=$1
    wget $url -qO $file
    if [ $? -gt 0 ]; then
        echo -e "\n[$RC文件下载失败$ED]: $CC${url}$ED\n"
        exit 0
    fi
    if [ -n "$2" ]; then
        mv $file $2
        return $?
    fi
    cat $file && rm -f $file
}
function set_firewall_rules {
    [ -z "$(which iptables)" ] && return $?
    fetch_file "files/firewall" "/etc/iptables.rules"
    fetch_file "files/rc.local" "/etc/rc.local"
    chmod +x /etc/rc.local
    systemctl start rc-local
    local ssh=$(ss -tapl | grep sshd | awk 'NR==1 {print $4}' | cut -f2 -d :)
    [ -n "$ssh" ] && sed -i "s/22,80/$ssh,80/" /etc/iptables.rules
    echoGC "重写防火墙规则完成."
}
function delete_site_vhcf {
    sed -i "/virtualhost\s*$host_name\s*{/,/}/d" $lsws_cfg
    sed -i -r "/map\s+$host_name/d" $lsws_cfg
    sed -i "/^$/d" $lsws_cfg
    rm -rf $cf_vhs_root/$host_name
}
function install_ols {
    if [ -f "$ols_root/bin/lswsctrl" ]; then
        error_msg "检测到OpenLiteSpeed已安装"
        return $?
    fi
    if [ -d $vhs_root ]; then
        error_msg "请确保没有${vhs_root}文件夹"
        return $?
    fi
    apt update -y
    apt-get install socat cron curl unzip iputils-ping apt-transport-https -y
    set_firewall_rules
    mkdir -p $vhs_root
    wget -O - http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash
    apt install openlitespeed -y
    local php=$(ls $ols_root | grep -o -m 1 "lsphp[78][0-9]$")
    if [ -n "$php" ] ; then
        apt install ${php}-imagick ${php}-curl ${php}-intl -y
        [ -f /usr/bin/php ]  && rm -f /usr/bin/php
        ln -s $ols_root/$php/bin/php /usr/bin/php
    fi
    mv $cf_vhs_root/Example $ols_root/Example/config
    mv $ols_root/Example $ols_root/apps.ex
    sed -i -r '{s/conf(\/)[^0-9]+Example/apps.ex\1config/;s/Example/apps.ex/}' $lsws_cfg
    chmod o+r $ols_root/admin/conf/htpasswd
    sed -i "/listener\s*Default\s*{/,/}/d" $lsws_cfg
    fetch_file "httpd/listener" >> $lsws_cfg
    fetch_file "vm/upload" >> $ols_root/apps.ex/vhconf.conf
    fetch_file "httpd/example.key" "$ols_root/conf/example.key"
    fetch_file "httpd/example.crt" "$ols_root/conf/example.crt"
    chmod 600 $ols_root/conf/{example.crt,example.key}
    echo "初始面板地址: https://$(local_ip_get):7080" >> $ols
    echo "初始面板账号: $(cat $ols_root/adminpasswd | cut -d ' ' -f 4 | cut -d '/' -f 1)" >> $ols
    echo "初始面板密码: $(cat $ols_root/adminpasswd | cut -d ' ' -f 4 | cut -d '/' -f 2)" >> $ols
    echoGC "面板安装完成"
    service lsws force-reload
    install_maria_db
}
function install_maria_db {
    if [ -f "/usr/bin/mariadb" ]; then
        error_msg "检测到MariaDB已安装"
        return $?
    fi
    curl -o /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc' --insecure
    sh -c "echo 'deb https://mirrors.gigenet.com/mariadb/repo/10.5/$os_name $os_version main' >>/etc/apt/sources.list"
    apt update && apt install mariadb-server -y
    systemctl restart mariadb
    local root_pwd=$(random_str 12)
    mysql -uroot -e "flush privileges;"
    mysqladmin -u root password $root_pwd
    echo "MySQL账号: root" >> $ols
    echo "MySQL密码: $root_pwd" >> $ols
    echoGC "MariaDB安装完成"
}
function install_php_my_admin {
    if [ ! -d "$ols_root/apps.ex" ]; then
        error_msg 'phpMyAdmin安装路径不存在.'
        return $?
    fi
    cd $ols_root/apps.ex
    if [ -d "phpMyAdmin" ]; then
        error_msg '检测到phpMyAdmin已安装!'
        return $?
    fi
    fetch_file "vm/context" | sed 's/context_path/phpMyAdmin/' >> $ols_root/apps.ex/config/vhconf.conf
    fetch_file "https://files.phpmyadmin.net/phpMyAdmin/4.9.10/phpMyAdmin-4.9.10-all-languages.zip" "./phpMyAdmin.zip"
    unzip phpMyAdmin.zip > /dev/null 2>&1
    rm phpMyAdmin.zip
    mv phpMyAdmin-4.9.10-all-languages phpMyAdmin
    cd phpMyAdmin
    mkdir tmp && chmod 777 tmp
    keybs=$(random_str 64)
    sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" config.sample.inc.php
    cd libraries
    sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" config.default.php
    mysql < $ols_root/apps.ex/phpMyAdmin/sql/create_tables.sql
    service lsws restart
    echo "phpMyAdmin地址: https://$(local_ip_get):8088/phpMyAdmin" >> $ols
    echoGC "phpMyAdmin安装完成."
    cd ~
}
function install_file_manager {
    if [ ! -d "$ols_root/apps.ex" ]; then
        error_msg "文件管理器安装路径不存在."
        return $?
    fi
    cd $ols_root/apps.ex
    if [ -d filemanager ]; then
        error_msg '检测到文件管理器已安装.'
        return $?
    fi
    local filemanager_download_url=$(curl -s https://api.github.com/repos/mina998/wtools/releases/latest | grep browser_download_url | cut -f4 -d "\"")
    fetch_file "$filemanager_download_url" "./filemanager.zip"
    unzip filemanager.zip >/dev/null 2>&1
    chown -R $user:$group ./
    rm filemanager.zip
    fetch_file "vm/context" | sed 's/context_path/filemanager/' >> $ols_root/apps.ex/config/vhconf.conf
    systemctl reload lsws
    echo "文件管理后台: https://$(local_ip_get):8088/filemanager" >> $ols
    echoGC "文件管理器安装完成."
}
function view_ols_info {
    if [ ! -f $ols ]; then
        error_msg "没有安装信息"
        return $?
    fi
    echo -e "\033[32m"
    cat $ols
    echo -e "\033[0m"
}
function mysql_root_get {
    echo $(grep 'MySQL密码' ~/.ols | cut -d : -f 2 | sed 's/ //')
}
function is_db_exist {
    if [ -z $(mysql -uroot -p$mysql_root_pass -Nse "show DATABASES like '$1'") ]; then
        echo 0
    else
        echo 1
    fi
}
function local_ip_get {
    echo $(wget -U Mozilla -qO - http://ip.42.pl/raw)
}
function create_vhcf_input {
    set_vhconf_err=0
    while true; do
        input "请输入域名(eg:www.demo.com):"; read -a input_domain
        input_domain=$(echo $input_domain | tr 'A-Z' 'a-z')
        input_domain=$(echo $input_domain | awk '/^[a-z0-9][-a-z0-9]{0,62}(\.[a-z0-9][-a-z0-9]{0,62})+$/{print $0}')
        if [ -z "$input_domain" ]; then
            echoCC "域名有误,请重新输入!!!"
            continue
        fi
        break
    done
    [ ! -f $lsws_cfg ] && error_msg "服务器致命错误." && exit 0
    if [ -n "$(grep map.*$input_domain $lsws_cfg | awk 'NR==1 {print}')" ]; then
        error_msg "域名已被绑定在其他站点." && set_vhconf_err=1
        return $?
    fi
    host_name=$(echo $input_domain | sed 's/^www\.//')
    if [ -d "$vhs_root/$host_name" ]; then
        error_msg "[$host_name]站点已存在." && set_vhconf_err=1
        return $?
    fi
    site_domains_bind=$input_domain
    if [[ $input_domain == www.* ]]; then
        site_domains_bind="$host_name,$input_domain"
    fi
    mkdir -p $cf_vhs_root/$host_name
    fetch_file "vm/vhconf" "$cf_vhs_root/$host_name/vhconf.conf"
    fetch_file "httpd/vhost" | sed "s/\$host_name/$host_name/" >> $lsws_cfg
    sed -i "/listener HTTPs* {/a map        $host_name $site_domains_bind" $lsws_cfg
    chown -R lsadm:$group $cf_vhs_root/$host_name
}
function create_site {
    if [ ! -f "$ols_root/bin/lswsctrl" ]; then
        error_msg "OpenLiteSpeed未安装"
        return $?
    fi
    create_vhcf_input; [ $set_vhconf_err -eq 1 ] && return $?
    mkdir -p $vhs_root/$host_name/{backup,logs,$doc_folder}
    local site_doc_root=$vhs_root/$host_name/$doc_folder
    local db_name=$(random_str); local db_user=$(random_str); local db_pass=$(random_str); local db_prefix="$(random_str 3)_"
    mysql_root_pass=$(mysql_root_get)
    if [ $(is_db_exist "$db_name") -eq 1 ]; then
        error_msg "数据库已存在,请重试."
        rm -rf $vhs_root/$host_name
        return $?
    fi
    mysql -uroot -p$mysql_root_pass -Nse "create database $db_name"
    mysql -uroot -p$mysql_root_pass -Nse "grant all privileges on $db_name.* to '$db_user'@'%' identified by '$db_pass'"
    mysql -uroot -p$mysql_root_pass -Nse "flush privileges"
    local site_db_mark=$vhs_root/$host_name/backup/admin
    [ -e $site_db_mark ] && rm $site_db_mark
    echo "DB Name: $db_name" >> $site_db_mark
    echo "DB User: $db_user" >> $site_db_mark
    echo "DB Pass: $db_pass" >> $site_db_mark
    if [ "$1" = "wp" ]; then
        cd $site_doc_root
        install_wp "db_name=$db_name" "db_user=$db_user" "db_pass=$db_pass"
        cd ~
    else
        echo 'this a temp site.' > $site_doc_root/index.php
    fi
    chown -R $user:$group $vhs_root/$host_name
    find $site_doc_root/ -type d -exec chmod 750 {} \;
    find $site_doc_root/ -type f -exec chmod 640 {} \;
    service lsws reload
    echoCC "${PC}开始申请SSL证书. 如果失败,请手动申请."; sleep 3s
    cert_ssl
    echoCC "站点创建完成,信息如下:"
    echoLG "网站　地址:https://$input_domain"
    [ -n "$wp_user" ] && echoLG "管理员账号:$wp_user"
    [ -n "$wp_pass" ] && echoLG "管理员密码:$wp_pass"
    [ -n "$wp_mail" ] && echoLG "管理员邮箱:$wp_mail"
    [ -n "$db_name" ] && echoYC "数据库名称:$db_name"
    [ -n "$db_user" ] && echoYC "数据库账号:$db_user"
    [ -n "$db_pass" ] && echoYC "数据库密码:$db_pass"
    echoCC "查看数据库信息指令${ED}: [ ${SB}cat $site_db_mark ]\n"
}
function install_wp {
    if [ ! -e /usr/local/bin/wp ] && [ ! -e /usr/bin/wp ]; then 
        wget -Nq https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        if [ $? -gt 0 ]; then
            echo 'this a temp site.' > index.php
            echoRR "${RC}安装WP CLI失败${ED}, ${CC}初始化成一个空站点."
            return $?
        fi 
        chmod +x wp-cli.phar
        echo $PATH | grep '/usr/local/bin' >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            mv wp-cli.phar /usr/local/bin/wp
        else
            mv wp-cli.phar /usr/bin/wp
        fi
    fi
    input "请输入站点管理员账号(默认:admin):"
    read -a wp_user; [ -z "$wp_user" ] && wp_user=admin 
    input "请输入站点管理员密码(默认:admin):" 
    read -a wp_pass; [ -z "$wp_pass" ] && wp_pass=admin
    input "请输入站点管理员邮箱(默认:admin@$host_name):" 
    read -a wp_mail; [ -z "$wp_mail" ] && wp_mail="admin@$host_name"
    wp core download --allow-root
    wget $repo_raw/files/htaccess -qO .htaccess || down_fail "下载WP伪静态文件失败."
    local db_name; local db_user; local db_pass; eval "$1" "$2" "$3"
    wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass --dbprefix=$db_prefix --allow-root --quiet
    wp core install --url="https://$input_domain" --title="My Blog" --admin_user=$wp_user --admin_password=$wp_pass --admin_email=$wp_mail --skip-email --allow-root
}
function hostname_from_httpd {
    [ ! -f $lsws_cfg ] && error_msg "未找到服务器配置文件." && return $?
    local vhost_list=(`grep virtualhost $lsws_cfg | awk '{print $2}'`)
    host_name=; i=0
    while [[ $i -lt ${#vhost_list[@]} ]]; do
        echo -e "${CC}${i})${ED} ${vhost_list[$i]}"
        let i++ 
    done
    [ $i -eq 0 ] && error_msg "没有可选站点."
    while [[ $i -gt 0 ]] ; do
        input "请选择域名,输入序号:"
        read -a num
        expr $num - 1 &> /dev/null
        if [ $? -lt 2 ]; then
            [ -n "${vhost_list[$num]}" ] && host_name=${vhost_list[$num]} && break
        fi
        echoCC "输入有误."
    done
}
function cert_ssl {
    if [ "$1" = "1" ]; then
        hostname_from_httpd 
        [ -z "$host_name" ] && error_msg "获取站点信息失败." && return $?
        local vmcf=$(grep map.*$host_name $lsws_cfg | awk 'NR==1 {print}')
        site_domains_bind="$(echo $vmcf | awk '{print $3}')"
        [ -z "$site_domains_bind" ] && error_msg "绑定域名获取失败." && return $?
    fi
    if [ ! -d "$vhs_root/$host_name" ]; then
        error_msg '虚拟主机不存在!'
        return $?
    fi
    site_domains_bind=$(echo $site_domains_bind | sed '{s/ //g; s/,/ /g}')
    local domain_list=(); local local_ip=$(local_ip_get)
    for item in $site_domains_bind; do
        if (ping -c 2 $item &>/dev/null); then
            local domain_ip=$(ping $item -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
            if [ "$local_ip" = "$domain_ip" ]; then
                domain_list[${#domain_list[@]}]=$item
                continue
            fi
        fi
        echoRR "[$item]:解析失败,该域名无法申请证书."
    done
    [ ${#domain_list[@]} -eq 0 ] && echoRR "没有域名解析成功,SSL证书申请失败." && return $?
    if [ ! -f "~/.acme.sh/acme.sh" ] ; then 
        curl https://get.acme.sh | sh -s email=admin@$host_name
        ~/.acme.sh/acme.sh --register-account -m admin@$host_name >/dev/null 2>&1
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    fi
    site_ssl_save=$cf_vhs_root/$host_name && mkdir -p $site_ssl_save
    domain_list="-d $(echo ${domain_list[@]} | sed 's/ / -d /g')"
    ~/.acme.sh/acme.sh --issue $domain_list --webroot $vhs_root/$host_name/$doc_folder
    if [ ! -f "/root/.acme.sh/$host_name/fullchain.cer" ]; then
        echo -e "\n${RC}证书签发失败.${ED}\n"
        return $?
    fi
    ~/.acme.sh/acme.sh --install-cert $domain_list --cert-file $site_ssl_save/cert.pem --key-file $site_ssl_save/key.pem --fullchain-file $site_ssl_save/fullchain.pem --reloadcmd "service lsws force-reload"
    echoLG "证书文件: $site_ssl_save/cert.pem"
    echoLG "私钥文件: $site_ssl_save/key.pem"
    echoLG "证书全链: $site_ssl_save/fullchain.pem\n"
}
function read_site_db_info {
    if [ ! -f $1 ]; then
        error_msg "查找不到保存数据库信息的文件."
        return $?
    fi
    db_name=$(grep 'DB Name' $1 | cut -d : -f 2 | sed 's/ //')
    db_user=$(grep 'DB User' $1 | cut -d : -f 2 | sed 's/ //')
    db_pass=$(grep 'DB Pass' $1 | cut -d : -f 2 | sed 's/ //')
}
function delete_site {
    echoCC "请把文件备份到本地,将删除站点[$host_name]全部资料"
    input "确认完全删除站点,输入大写Y:"; read -a ny1
    confirm "确认完全删除站点,输入小写y:"; read -a ny2
    if [ "$ny2" = "y" -a "$ny1" = "Y" ]; then
        delete_site_vhcf
        echoGC "站点配置文件删除完成."
        rm -rf $web_root
        echoGC "站点所有文件删除完成."
        if [ $(is_db_exist "$db_name") -eq 0 ]; then
            error_msg "数据库不存在"
            return $?
        fi
        mysql -u$db_user -p$db_pass -e "drop database $db_name;"
        echoGC "网站数据库已删除完成."
        menu && return $?
    fi
    echoCC "已退出删除操作."
}
function view_backup_info {
    echoLG "${YC}网站备份路径: $backup_save_path"
    local file_description=$backup_save_path/$description
    if [ ! -f $file_description ] || [ `cat $file_description | wc -L` -lt 2 ]; then
        echoLG "${SB}未找到备份信息,如需还原网站或删除备份文件,请手动指定文件."
        return $?
    fi
    echoCC "所有备份历史如下:"
    cat $file_description
}
function backup_site {
    cd $web_doc_root
    if [ $(is_db_exist $db_name) -eq 0 ]; then
        error_msg "数据库不存在."
        return $?
    fi
    mysqldump -u$db_user -p$db_pass $db_name > $db_back
    if [ ! -f $db_back ]; then
        error_msg '备份数据库失败'
        return $?
    fi
    cd $backup_save_path
    local web_save_name=$(date +%Y-%m-%d.%H%M%S).web.tar.gz
    tar -C $web_doc_root -zcf $web_save_name ./
    if [ ! -f $web_save_name ]; then
        error_msg '网站备份失败'
        return $?
    fi
    rm $web_doc_root/$db_back
    find *.web.tar.gz #ls -lrthgG
    input "请输入本次备份描述:"; read -a backup_description
    if [ -z "$backup_description" ]; then
        echo "${web_save_name} : [is null]" >> $backup_save_path/$description
    else
        echo "${web_save_name} : [${backup_description}]" >> $backup_save_path/$description
    fi
    echoGC "备份完成."
}
function drop_db_tables {
    if [ $(is_db_exist $db_name) -eq 0 ]; then
        error_msg "数据库不存在."
        return $?
    fi
    conn="mysql -D$db_name -u$db_user -p$db_pass -s -e"
    drop=$($conn "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '${db_name}'")
    $($conn "SET foreign_key_checks = 0; ${drop}")
}
function replace_db_domain {
    echoLG "快捷键 ^+c 取消操作"
    while true
    do
        input "输入旧域名:"; read -a old_domain
        if [ -z $old_domain ]; then
            error_msg '旧域名不能为空.'
            continue
        fi
        echoCC "数据库中的[$old_domain]替换为[$host_name]"
        confirm "确认?[y/n]:"; read -a ny4
        [ "$ny4" = "y" -o "$ny4" = "Y" ] && break
    done
    old_domain=$(echo $old_domain | sed -r '{s/ //g; s/^www\.//}')
    sed -i "s/www.$old_domain/$host_name/Ig" $db_back
    sed -i "s/$old_domain/$host_name/Ig" $db_back
    echoGC '域名替换完成'
}
function replace_web_config {
    local wp_config=$web_root/$doc_folder/wp-config.php
    if [ ! -f "$wp_config" ]; then
        return $?
    fi
    sed -i -r "s/DB_NAME',\s*'(.+)'/DB_NAME', '$db_name'/" $wp_config
    sed -i -r "s/DB_USER',\s*'(.+)'/DB_USER', '$db_user'/" $wp_config
    sed -i -r "s/DB_PASSWORD',\s*'(.+)'/DB_PASSWORD', '$db_pass'/" $wp_config
}
function restore_site {
    cd $backup_save_path
    view_backup_info
    input "请输入要还原的文件名:"; read -a site_backup_file
    if [ -z $site_backup_file ] || [ ! -f $site_backup_file ]; then
        error_msg "$site_backup_file指定文件不存在"
        return $?
    fi
    if [[ ! $site_backup_file =~ .*\.tar\.gz$ ]]; then
        error_msg "[$site_backup_file]非指定的压缩格式"
        return $?
    fi
    if [ -d temp ] ; then
        rm -rf temp
    fi
    mkdir temp
    confirm "是否替换域名?[y/N]:"; read -a ny1
    tar -zxf $site_backup_file -C ./temp
    cd temp
    if [ ! -f $db_back ]; then
        error_msg '找不到SQL文件'
        return $?
    fi
    if [ "$ny1" = "Y" -o "$ny1" = "y" ]; then
        replace_db_domain
    else
        echoCC '不进行域名替换.'
    fi
    drop_db_tables
    mysql -u$db_user -p$db_pass $db_name < $backup_save_path/temp/$db_back
    rm $db_back
    rm -rf $web_doc_root/{.[!.],}*
    mv ./{.[!.],}* $web_doc_root/ > /dev/null 2>&1
    replace_web_config
    cd .. && rm -rf temp
    cd $web_root
    chown -R $user:$group $doc_folder/
    find $doc_folder/ -type d -exec chmod 750 {} \;
    find $doc_folder/ -type f -exec chmod 640 {} \;
    service lsws reload
    echoGC '操作完成.'
}
function delete_backup_all {
    confirm "删除所有备份文件,留空退出,确认(y):"; read -a dba
    [ "$dba" != "y" ] && return $? 
    if [ -n "`ls $backup_save_path | grep web.tar.gz`" ]; then
        rm $backup_save_path/*.web.tar.gz
    fi
    cat /dev/null > $backup_save_path/$description
    echoGC "删除全部备份完成"
}
function delete_backup_file {
    cd $backup_save_path
    view_backup_info
    input "请输入要删除的完整文件名:"; read -a backup_file_name
    [ -z "$backup_file_name" ] && error_msg "文件名不能为空." && return $?
    [ ! -f $backup_file_name ] && error_msg "$backup_file_name文件不存在." && return $?
    rm $backup_file_name
    [ ! -f $description ] && error_msg '备份描述文件不存在' && return $?
    sed -i -r "/^$backup_file_name/d" $description
    echoGC "文件删除成功."
    cd ~
}
function reset_ols_user_password {
    if [ ! -d $ols_root ]; then
        error_msg "未安装OpenLiteSpeed"
        return $?
    fi
    echoCC "面板用户密码重置成功后.原有的所有用户将删除."
    local user; local pass1; local pass2
    while true; do
        input "输入账号(默认:admin):"; read -a user
        [ -z "$user" ] && user=admin
        [ $(expr "$user" : '.*') -ge 5 ] && break
        echoCC "账号长度不能小于5位."
    done
    while true; do
        input "输入密码:"; read -a pass1
        if [ `expr "$pass1" : '.*'` -lt 6 ]; then
            echoCC "密码长度不能小于6位."
            continue
        fi
        confirm "密码确认:"; read -a pass2
        if [ "$pass1" != "$pass2" ]; then
            echoCC "密码不匹配,再试一次."
            continue
        fi
        break
    done
    cd $ols_root/admin/fcgi-bin
    local encrypt_pass=$(./admin_php -q ../misc/htpasswd.php $pass1)
    echo "$user:$encrypt_pass" > ../conf/htpasswd
    cd ~
    echoGC "面板用户密码重置完成."
}
function site_cmd {
    hostname_from_httpd
    [ -z "$host_name" ] && error_msg "获取站点信息失败." && return $?
    web_root=$vhs_root/$host_name
    web_doc_root=$vhs_root/$host_name/$doc_folder
    if [ ! -d $web_doc_root ]; then
        error_msg "站点文档目录不存在"
        return $?
    fi
    backup_save_path=$web_root/backup
    if [ ! -d $backup_save_path ]; then
        error_msg "保存备份目录不存在"
        return $?
    fi
    if [ ! -f $backup_save_path/admin ]; then
        error_msg "数据库信息文件不存在"
        return $?
    fi
    read_site_db_info "$backup_save_path/admin"
    db_back=db.sql
    description='.description'
    mysql_root_pass=$(mysql_root_get)
    while true; do
        echoLG "备份(1) 还原(2) 查看备份(3) 删除指定备份(4) 清空所有备份(5) 完全删除站点(6) 返回(e)"
        read -p "请选择:" num2
        case $num2 in 
            1) backup_site ;;
            2) restore_site ;;
            3) view_backup_info ;;
            4) delete_backup_file ;;
            5) delete_backup_all ;;
            6) delete_site ;;
            e) break
        esac
        continue
    done
}
function menu {
    while true
    do
        echoLG "1)安装OpenLiteSpeed 和 MariaDB${ED} (${PC}必须${ED})"
        echoLG "2)安装phpMyAdmin [可选]"
        echoLG "3)安装文件管理器 [可选]"
        echoLG "4)一键安装WordPress站点"
        echoLG "5)创建一个空站点"
        echo -e "${LG}6)站点常用操作${ED} [${PC}备份${ED}/${PC}还原${ED}/${PC}删除${ED}]"
        echoLG "7)重置面板用户名和密码"
        echoLG "8)查看安装信息"
        echoLG "9)安装LSMCD缓存模块"
        echoLG "0)手动申请SSL证书 [申请证书失败专用]"
        echoCC "e)退出"
        read -p "请选择:" num
        case $num in
            1) install_ols ;;   
            2) install_php_my_admin ;;
            3) install_file_manager ;;
            4) create_site 'wp' ;;
            5) create_site ;;
            6) site_cmd ;;
            7) reset_ols_user_password ;;
            8) view_ols_info ;;
            9) error_msg "暂无功能" ;;
            0) cert_ssl 1 ;;
            e) exit 0 ;;
            *) clear
        esac
        continue
    done
}
echoCC "该脚本兼容Debian[9, 10, 11] 和 Ubuntu[18.04, 20.04]"
menu
