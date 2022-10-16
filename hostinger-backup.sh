#!/bin/bash

#### 站点备份 GITHUB版

#设置本地仓库路径(站点文档根路径) 后缀不加/   *
site_doc_root=/home/u362533795/domains/istoragebox.com/public_html
#带用户名密码远程仓库地址   *
repo_to=https://username:password@github.com/username/repo.git
#数据库名称  *
db_name=wordpressdb2
#数据库用户名  *
db_user=soroy
#数据库密码  *
db_pass=463888

#远程分支
branch=master
#导出数据文件名
db_file=db.sql.gz

#切换工作路径
cd $site_doc_root
# 初始化一个仓库
if [ -z `ls -a | grep '.git'` ] ; then
	git config --global user.email "pofoy@qq.com"
	git config --global user.name "demo88"
	git init 
	git config --global --add safe.directory $site_doc_root
	git checkout -B $branch
	git remote add origin $repo_to
fi

#检测数据库是否存在
if [ -z `mysql -u$db_user -p$db_pass -Nse "show DATABASES like '$db_name'"` ] ; then
	echo "数据库不存在"
	exit 0
fi
# 如果本地存在历史备份就删除
if [ -e $db_file ] ; then
	rm $db_file
fi
# 导出MySQL数据库
mysqldump -u$db_user -p$db_pass $db_name | gzip -9 - > $db_file

git add .
git commit -m "$(date '+%Y-%m-%d %H:%M:%S')" > /dev/null
git push origin $branch

rm $db_file
