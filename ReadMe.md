# FastDDS 旧系统移植

## 工具链要求

- 系统: Ubuntu 18.04 / 20.04
- 编译器: GCC 7 / clang6

## 构建并安装

```bash
CFLAGS='-g3 -O3' CXXFLAGS='-g3 -O3' CMAKE_BUILD_TYPE=RelWithDebInfo FASTDDS_INTERNAL_DEBUG=OFF make shared
```
