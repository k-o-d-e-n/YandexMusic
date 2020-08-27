# YandexMusic

Partially implementation of Yandex Music API in Swift.
Thanks [MarshalX](https://github.com/MarshalX) for his [API Yandex Music](https://github.com/MarshalX/yandex-music-api) python library.

__Installation__

```
.package(url: "https://github.com/k-o-d-e-n/YandexMusic.git", from: "<%v%>")
```

### Application

Package also has simple console application to play your playlists and feed playlists.

<p align="center">
    <img src="Resources/app_screenshot.png">
</p>

It will the best for my weak computer on Linux :)

__CPU__

<p align="center">
    <img src="Resources/app_browser_cpu.png">
</p>

__Memory__

<p align="center">
    <img src="Resources/app_browser_memory.png">
</p>

__Usage__
    
    <executable> <CLIENT_ID[:CLIENT_SECRET]> [--options]
    
__Compile and run__

```
swift build
swift run
```

Or generate and run Xcode project `swift package generate-xcodeproj`.
