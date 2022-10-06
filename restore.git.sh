#!/bin/bash

#### 从GITHUB 还原

# 带用户名密码远程仓库地址 *
repo_url=https://username:password@github.com/username/repo.git
#
if [[ -z $1 ]]; then
    echo 'ID参数不存在'
    exit 0
fi
# 提交ID
commit_id=$1
# 分支名
branch_name=master
# 站点文档文件夹
web_doc_folder=wordpress
# 站点文档根绝对路径 *
site_doc_root=/www/site.com/$web_doc_folder
# 数据库名 *
db_name=xxxxx
# 数据库用户 *
db_user=xxxxx
# 数据库密码 *
db_pass=xxxxx
# 权限用户
user=nobody
# 所属组
group=nogroup
#判断数据库是否存在
if [ -z `mysql -u$db_user -p$db_pass -Nse "show DATABASES like '$db_name'"` ] ; then
    echo "数据库不存在"
    exit 0
fi
# 克隆仓库
git clone $repo_url -b $branch_name temp
# 删除当前文件
cd temp && rm -rf *
# 恢复到指定提交
git reset --hard $commit_id
# 解压SQL文件
gzip -d db.sql.gz
# 删除数据库所有表
conn="mysql -D$db_name -u$db_user -p$db_pass -s -e"
drop=$($conn "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '${db_name}'")
$($conn "SET foreign_key_checks = 0; ${drop}")
# 导入SQL文件
mysql -u$db_user -p$db_pass $db_name < ./db.sql
# 删除SQL文件
rm db.sql
# 删除网站文件
rm -rf $site_doc_root/*
# 还原备份文件
mv * $site_doc_root/
#
cd $site_doc_root/..
# 设置权限
chown -R $user:$group $web_doc_folder
find $web_doc_folder -type d -exec chmod 750 {} \;
find $web_doc_folder -type f -exec chmod 640 {} \;
# 清理
cd .. && rm -rf temp
