# LaziMakr
LazyMaker 是一款 Xcode Source Editor Extension，其对编辑器的现有功能进行扩展，旨在简化开发流程，提升效率。
A Xcode Extension which can automatically generate getter/setter codes.

## 功能一览：
V1.0 支持 OC属性的 Getter / Setter方法代码生成，主要特性如下。

1. 常见属性写法全支持
2. 重要关键字保留，nonull不丢
3. 只需光标定位，即可一键生成代码
4. 单行，多行，跨行，跨类，随便选
5. 智能计算代码生成位置，懂你意思
6. 不重复生成，智能补全@synthesize

# 使用方法
## 下载安装
download代码后在zip中解压dmg或者自行在Xcode中进行编译找到dmg文件
![Image text](https://github.com/junqhao/ImgSaver/blob/main/LaziMakr/lzmk_1.jpeg)

## 设置系统偏好 
在系统偏好设置-扩展中 选择使用LazyMaker，建议重启Xcode以正常使用
![Image text](https://github.com/junqhao/ImgSaver/blob/main/LaziMakr/lzmk_2.jpeg)

## 设置快捷键 
设置快捷操作（推荐 option + G/S/L）
![Image text](https://github.com/junqhao/ImgSaver/blob/main/LaziMakr/lzmk_3.jpeg)

## 禁用
在系统偏好设置-扩展中 选择取消勾选 LazyMaker 或者直接卸载 LaziMakr App 即可

## 注意
Apple对Extension作了诸多限制，比如不允许跨文件操作，因此如果在 .h 中生成代码，需要手动copy到 .m 中
