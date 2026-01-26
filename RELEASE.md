# BFLottieWebView 发布流程

## Pod 信息

- 名称: BFLottieWebView
- 当前版本: 0.1.0
- GitHub 仓库: https://github.com/mirbf/BFLottieWebView
- 作者: Bfchen (2946779829@qq.com)

## 首次发布（GitHub + CocoaPods）

### 1. 创建 GitHub 仓库

在 GitHub 创建仓库: `mirbf/BFLottieWebView`

### 2. 初始化 Git 仓库并提交

```bash
cd /Users/bigger/Desktop/Pod/BFLottieWebView

git init -b main
git add .
git commit -m "Initial commit: BFLottieWebView"
```

### 3. 绑定远程并推送

```bash
git remote add origin git@github.com:mirbf/BFLottieWebView.git
git push -u origin main
```

### 4. 打 tag（必须与 podspec 版本一致）

```bash
git tag 0.1.0
git push origin 0.1.0
```

### 5. 本地验证（可选）

```bash
pod lib lint BFLottieWebView.podspec --allow-warnings
pod spec lint BFLottieWebView.podspec --allow-warnings
```

### 6. 发布到 CocoaPods Trunk

首次需要注册：

```bash
pod trunk register 2946779829@qq.com 'Bfchen' --description='Mac'
# 点击邮件中的验证链接
```

发布：

```bash
pod trunk push BFLottieWebView.podspec --allow-warnings
```

## 后续版本更新

1) 修改代码
2) 更新 `BFLottieWebView.podspec` 的 `s.version`
3) `git commit` + `git push`
4) `git tag <version>` + `git push origin <version>`
5) `pod trunk push BFLottieWebView.podspec --allow-warnings`

## 注意

- podspec 里的 `s.source` tag 必须存在并与版本号一致
- 不要修改已发布版本的 tag 指向；需要修复请发布新版本
