# SwiftUI macOS Embedded Terminal Shell Picker

## 简介

这个 Demo 用 SwiftUI 做一个 macOS 窗口。

窗口里直接嵌了一个真实 terminal。
顶部有一个 shell 选择器，可以切到 `zsh`、`bash`、`sh`，以及当前机器 `/etc/shells` 里存在的其它 shell。

terminal 本身不是手搓假 UI，而是接了 `SwiftTerm`，底层走 pseudo terminal，所以能正常跑交互式 shell。

## 快速开始

### 环境要求

- macOS 14+
- Xcode 15+
- XcodeGen

安装 XcodeGen：

```bash
brew install xcodegen
```

### 运行

```bash
cd swiftui-macos-terminal-shell-picker-demo
./scripts/build.sh
open build/DerivedData/Build/Products/Debug/SwiftUIMacOSTerminalShellPickerDemo.app
```

如果你想直接生成 Xcode 工程再点开：

```bash
cd swiftui-macos-terminal-shell-picker-demo
xcodegen generate
open SwiftUIMacOSTerminalShellPickerDemo.xcodeproj
```

## 概念讲解

### 第一部分：SwiftUI 外壳

窗口主体很薄，只做两件事：

1. 顶部放一个 `Picker`
2. 下方放 terminal view

代码核心：

```swift
VStack(spacing: 0) {
    HStack(spacing: 12) {
        Text("Shell")

        Picker("Shell", selection: $selectedShellPath) {
            ForEach(shells) { shell in
                Text("\(shell.title)  \(shell.path)").tag(shell.path)
            }
        }
    }

    Divider()

    EmbeddedTerminalView(shell: selectedShell)
}
```

这里 `Picker` 只改当前 shell 路径。
真正重启 terminal 的动作，交给下面的 AppKit bridge。

### 第二部分：用 NSViewRepresentable 嵌 AppKit terminal

`SwiftTerm` 提供的是 AppKit `NSView`。
SwiftUI 里要显示它，最直接就是包一层 `NSViewRepresentable`：

```swift
struct EmbeddedTerminalView: NSViewRepresentable {
    let shell: TerminalShell

    func makeNSView(context: Context) -> TerminalContainerView {
        let view = TerminalContainerView()
        view.run(shell: shell)
        return view
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        nsView.run(shell: shell)
    }
}
```

重点不在 SwiftUI，而在 `TerminalContainerView`。
它内部持有 `LocalProcessTerminalView`，shell 改了就 terminate 旧进程，再 start 新进程。

### 第三部分：shell 来源

不是把 `zsh`、`bash` 写死完事。

Demo 会先读 `/etc/shells`，把当前机器可用 shell 列出来。
如果读取失败，再回退到：

```swift
["/bin/zsh", "/bin/bash", "/bin/sh"]
```

这样一来：

- 常见机器默认能看到 `zsh`
- 老环境还能切 `bash`
- 特殊机器如果有别的 shell，也能自动出现

## 完整示例

```swift
final class TerminalContainerView: NSView, LocalProcessTerminalViewDelegate {
    private let terminalView = LocalProcessTerminalView(frame: .zero)
    private var currentShell: TerminalShell?

    func run(shell: TerminalShell) {
        guard currentShell != shell else {
            return
        }

        terminalView.terminate()
        currentShell = shell
        terminalView.startProcess(executable: shell.path, currentDirectory: initialDirectory)
    }
}
```

这段代码就是核心控制面：

- 先判断 shell 是否真的变了
- 变了就停掉旧 shell
- 再用新 executable 拉起 terminal 里的本地进程

## 注意事项

- 这是 macOS App，不是 iOS
- terminal 依赖本机 shell，可执行路径必须真实存在
- 当前实现每次切 shell 都会重建进程，原会话不会保留
- 这是单 terminal demo，暂时不做标签页、多会话、命令历史持久化
- Demo 当前锁定 `SwiftTerm 1.10.1`
- 原因不是功能依赖老版本，而是更新版本默认会编译 Metal shader；如果本机没装 `Metal Toolchain`，命令行构建会失败

## 完整讲解（中文）

这次需求重点不是“做个黑框”，而是“窗口里要真能跑 shell，而且能切 zsh/bsh/sh 这类解释器”。

如果只用 `Process` + `Pipe`，很快会撞到两个问题：

1. 很多 shell 在非 TTY 下行为不对
2. ANSI 控制字符、光标移动、清屏这些显示会乱

所以这个 Demo 直接换成 `SwiftTerm`。
它已经把 terminal emulation 和 pseudo terminal 这层做好了。
我们只需要做一层很薄的 SwiftUI 包装。

整个结构分 3 层：

1. `ContentView` 负责 shell picker
2. `EmbeddedTerminalView` 负责把 AppKit view 接进 SwiftUI
3. `TerminalContainerView` 负责真正启动和切换 shell

这样拆的好处很直接：

- UI 层很薄
- terminal 生命周期集中
- shell 切换逻辑只有一处

如果你后面要继续扩：

- 加工作目录输入框
- 加多个 terminal tab
- 把当前 cwd 显示到窗口标题
- 加“重启 shell”按钮

都可以继续堆在这个结构上，不用推倒重来。
