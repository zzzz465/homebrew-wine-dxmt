---
name: wine-dxmt 11.8_cw1 custom build workflow
description: MacPorts 기반으로 wine-staging 11.8 에 CrossOver CEF 주입 + Proton mfreadwrite 패치를 포팅 → Gcenx 호환 레이아웃 tarball 패키징 → cask 배포까지의 전체 작업 기록. 11.7_cw1 (로컬 검증만, 미공개) 위에 누적되어 11.8_cw1 이 cw1 시리즈의 첫 공개 배포.
type: reference
originSessionId: 58e20882-284c-48ff-94e2-7d4d83131458
---
# wine-dxmt 11.8_cw1 — 빌드 작업 기록 (2026-04-20 ~ 05-11)

> 원본 tap repo: `~/Documents/git/github-cloud/homebrew-wine-dxmt`
> 병행 macports overlay: `~/Documents/git/github-cloud/macports-wine`

## 0. 11.8_cw1 업데이트 요약 (2026-05-11)

11.7_cw1 위에 누적된 변경 — **11.7_cw1 은 공개 release 안 함**. 따라서 tap 사용자 관점에서는 11.6_1 → 11.8_cw1 한 번에 점프.

| 항목 | 변경 |
|---|---|
| wine source | `wine-11.7` → `wine-11.8` (`dlls/kernelbase/process.c` 두 버전 동일 → CW-HACK 패치 변경 없음) |
| Gcenx/macports-wine fork | `d08246f` → `5a5fa99` 머지 (11.8 + `llvm-mingw 20260505` + `mingw-w64-wine-mono 11.0.0 → 11.1.0`) |
| 신규 패치 | `proton-mfreadwrite-164af86d.diff` ([ValveSoftware/wine 164af86d](https://github.com/ValveSoftware/wine/commit/164af86dd770f975cdff3e09884f14ebc14b856b)) — 11.6_1 에서 binary DLL 교체로 적용됐다가 11.7_cw1 에서 제외됐던 mfreadwrite 패치를 이번에 source patchfile 로 정식 편입. cask postflight 의 binary 복사 단계 제거. |
| Portfile | `patchfiles-append` 블록에 mfreadwrite diff 1줄 추가 |
| 빌드 산출물 | `/tmp/wine-pkg-11.8_cw1/wine-staging-11.8_cw1-osx64.tar.xz` (267.8 MB) |
| sha256 | `868a377ff0f1d0c0d77b9be2762362450433634cc284959ad8f879b3b27caea9` |
| `package-wine.py` 변경 | `VERSION = "11.7"` → `VERSION = "11.8_cw1"` (1줄) |

검증 (build 로그 `/tmp/wine-build-20260511-150320.log`):
- `Applying cw-hack-steam-cef-injection.diff` ✅
- `Applying proton-mfreadwrite-164af86d.diff` ✅ (`patching file 'dlls/mfreadwrite/reader.c'`)
- `wine --version` → `wine-11.8 (Staging)` ✅
- `strings .../kernelbase.dll` → `CreateProcessInternalW.steamwebhelperexeW`, `CrossOver hack changing command line to %s` ✅


## 1. 배경 / 문제

- 기존 `wine-dxmt` cask (v11.6_1) 는 Gcenx/macOS_Wine_builds 의 prebuilt `wine-staging-11.6_1-osx64.tar.xz` 를 베이스로 사용
- 설치 후 `wine-dxmt-steam` 실행 시 **Steam UI 렌더링 실패** 관측
  - Steam 프로세스는 뜨는데 클라이언트 창이 안 보임
  - 로그: CEF GPU subprocess 에서 SwapChain allocation 실패 → steamwebhelper.exe 크래시
  - 루트 원인: **winemac + DXMT 환경에서 CEF multi-process GPU 가 동작 안 함**
- 해결법은 CrossOver 가 20년 넘게 유지해 온 CW-HACK: steamwebhelper 에 `--in-process-gpu --disable-gpu --no-sandbox` 주입해서 GPU subprocess 자체를 비활성화

## 2. 핵심 발견 — Gcenx prebuilt 는 CW-HACK 미포함

지금까지의 가정 ("Gcenx prebuilt 가 CX HACK 을 이미 포함") 은 **잘못됐음**.

검증 방법:
```
strings ~/Wine/dxmt/11.6_1/lib/wine/x86_64-windows/kernelbase.dll \
  | grep -iE "crossover hack|steamwebhelper|in-process-gpu"
```
→ 0건 (모든 Gcenx 버전에서 동일).

이유 (추정):
- `Gcenx/macports-wine` repo 가 2026-04-16 에 리셋됨 (commit `5c5bf577` "Commit everything")
- 과거 CW-HACK 을 포함했는지 여부는 이제 확인 불가 (git history 사라짐)
- Gcenx 릴리스 목록도 11.0_1 / 11.6_1 / 11.7 세 개만 남음 (11.4, 11.5 실제 삭제됨 — `git ls-remote` 로 태그 부재 확인)

결론: **과거 11.4/11.5 에서 Steam UI 가 떴던 건 CX HACK 이 빌드에 포함됐었기 때문일 가능성이 높고, 11.6_1 부터는 빠진 상태.** 따라서 우리가 직접 포팅해야 함.

## 3. 빌드 환경 — MacPorts

### 왜 MacPorts 인가
- Gcenx 본인이 MacPorts 기반으로 wine 을 빌드 (`Gcenx/macports-wine/emulators/wine-devel/Portfile`)
- Portfile fork + patch 1줄 추가만으로 Gcenx 와 동일한 ABI/레이아웃의 wine 을 얻을 수 있음
- Brew 로 수동 configure 하면 Portfile 에 녹아 있는 세부 옵션 (compiler.limit_flags, triplet 설정 등) 을 우리가 직접 관리해야 함 → 위험

### 설치 순서
```
# 1. MacPorts 설치 (sudo installer)
sudo installer -pkg /tmp/MacPorts-2.12.4-15-Sequoia.pkg -target /

# 2. port tree 동기화
sudo /opt/local/bin/port -v selfupdate

# 3. Gcenx macports-wine fork clone
cd ~/Documents/git/github-cloud
git clone https://github.com/Gcenx/macports-wine

# 4. local overlay 등록 (sources.conf 수정 — sudo 필요)
sudo sh -c 'cat > /opt/local/etc/macports/sources.conf <<EOF
file:///Users/do.kim/Documents/git/github-cloud/macports-wine [nosync]
rsync://rsync.macports.org/macports/release/tarballs/ports.tar.gz [default]
EOF'

# 5. local 디렉토리 PortIndex 생성
cd ~/Documents/git/github-cloud/macports-wine && /opt/local/bin/portindex

# 6. macports 빌드 유저가 overlay 접근할 수 있게 권한 조정
sudo chmod o+x ~ ~/Documents
sudo chgrp -R macports ~/Documents/git/github-cloud/macports-wine
sudo chmod -R g+rwX ~/Documents/git/github-cloud/macports-wine
sudo find ~/Documents/git/github-cloud/macports-wine -type d -exec chmod g+s {} \;
```

자동화 스크립트: `~/tmp/macports-add-overlay.sh`, `~/tmp/fix-overlay-perms.sh`

## 4. CW-HACK 패치

### 대상 함수
`dlls/kernelbase/process.c` 의 `CreateProcessInternalW()`.

### 적용 위치
wine 11.7 기준 line 543 (`app_name = name;` 다음) 에 hack block 삽입.

### 대상 프로세스
- `steamwebhelper.exe` — `--no-sandbox --in-process-gpu --disable-gpu`
- `SocialClubHelper.exe`, `Foxmail.exe`, `Battle.net.exe`, `UplayWebCore.exe`, `qwSubprocess.exe`, `WeChat.exe`, `Paradox Launcher.exe`, `rundll32.exe --no-sandbox` — 각각 필요 플래그 조합

### 의도적 제외
- `hack_steam_exe()` (steam.exe 32-bit cef 강제 + ForceBeta) — 2026 Steam 은 64-bit chromium 전환 완료라 불필요
- winemac.drv `is_rockstar_launcher_or_steamwebhelper()` / `needs_zorder_hack()` (CX HACK 19364/16565) — `macdrv_force_popup_order_front()` 라는 CrossOver 전용 Cocoa 함수를 새로 구현해야 하는 복잡도 때문에 보류

### 패치 파일 위치
`~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/files/cw-hack-steam-cef-injection.diff`

### Portfile 수정
`~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/Portfile` 에 한 블록 추가:
```tcl
patchfiles-append \
    cw-hack-steam-cef-injection.diff
```

### 검증
```
cd /tmp && rm -rf v4 && mkdir -p v4/dlls/kernelbase
curl -sL https://raw.githubusercontent.com/wine-mirror/wine/wine-11.7/dlls/kernelbase/process.c \
  > v4/dlls/kernelbase/process.c
cd v4 && patch -p1 --dry-run < ~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/files/cw-hack-steam-cef-injection.diff
```
→ DRY: OK, hunks succeed.

## 5. wine 빌드

```
~/tmp/wine-build.sh
# 내부적으로: sudo /opt/local/bin/port -v install wine-staging
```

소요: ~2시간 (deps 30분 + wine-staging 본체 30~60분 + wine-mono/gecko 다운로드).

진행도 체크:
```
~/tmp/wine-build-status.sh
# 또는: tail -f /tmp/wine-build-YYYYMMDD-HHMMSS.log
```

완료 후 결과물:
- 바이너리: `/opt/local/bin/wine*`
- wine 내부: `/opt/local/lib/wine/{i386-windows,x86_64-windows,x86_64-unix}/`
- wine-mono/gecko: `/opt/local/share/wine/`

검증:
```
strings /opt/local/lib/wine/x86_64-windows/kernelbase.dll \
  | grep -iE "crossover hack|steamwebhelper"
```
→ `CreateProcessInternalW.steamwebhelperexeW`, `CrossOver hack changing command line to %s` 출력되면 성공.

## 6. 패키징 — Gcenx 레이아웃으로 tarball

### 문제
- `/opt/local/bin/wine` 는 system lib 만 링크
- 하지만 `lib/wine/x86_64-unix/*.so` 들은 `/opt/local/lib/libinotify`, `/opt/local/lib/libpcap`, `@rpath/libgstreamer*` 등 참조
- `@rpath` 는 `LC_RPATH` 를 따라 resolve 되므로 패키징 시 LC_RPATH 도 재작성 필요

### 패키징 스크립트
`~/tmp/package-wine.py`

핵심 로직:
1. `Wine Staging.app/Contents/Resources/wine/` 스켈레톤 생성
2. `/opt/local/bin/wine*`, `/opt/local/lib/wine`, `/opt/local/share/wine` 복사
3. 복사된 Mach-O 파일들 재귀로 deps 탐색 (`otool -L` + @rpath 해석)
4. external dep 발견 → `.app/.../wine/lib/` 에 복사 + symlink 재생성
5. `install_name_tool -id @rpath/NAME` + `-change OLD @rpath/NAME`
6. wine 바이너리 `LC_RPATH /opt/local/lib` → 제거 후 `@loader_path/<rel to lib>` 추가
7. 모든 Mach-O 파일 `codesign --force --sign -` (ad-hoc)
8. `tar -cJf wine-staging-11.7_cw1-osx64.tar.xz`

주의:
- `@rpath/NAME` resolve 시 declared rpaths 외에 `loader_path` 자체와 `/opt/local/lib`, `/opt/local/Library/Frameworks/GStreamer.framework/Libraries` 를 fallback 으로 추가해야 GStreamer 내부 peer 참조가 풀림
- 그 외 빠졌던 liborc, libpcre2 등 transitive dep 도 이 fallback 으로 모두 감지됨
- 최종 외부 dylib 21개 (Gcenx 의 94개보다 적은 건 우리가 `+gstreamer` 의존 외에 추가 plugin framework 를 번들하지 않기 때문 — 실제 runtime 에서 필요한 건 모두 포함)

### 최종 산출물
- 파일: `/tmp/wine-staging-11.7_cw1-osx64.tar.xz` (216 MB)
- sha256: `31247ed4ae75d302034220f04ed095894270aad8c43de9cd9de3d6844fefab9c`

의존성 검증 (모든 link 가 pkg 내부 or system 으로 resolve 되는지):
```
python3 ~/tmp/package-wine.py  # 내장 validation 없음. 따로 돌리려면:
# 한 번에 검사하는 inline 스크립트는 이전 세션 기록 참고
```

## 7. cask 변경

### wine-dxmt.rb (main cask)
| 필드 | Before | After |
|---|---|---|
| `version` | `11.6_1` | `11.7_cw1` |
| `sha256` | Gcenx 11.6_1 해시 | `31247ed4...fab9c` |
| `url` | `...wine-dxmt-patches-11.6_1.tar.xz` (우리 patch overlay) | `...wine-staging-11.7_cw1-osx64.tar.xz` (full wine) |
| postflight #1 | Gcenx curl + tar | `cp -R #{staged_path}/Wine Staging.app/.../wine/ #{wine_dir}/` |
| postflight mfreadwrite | 있음 | **제거** (follow-up 으로 재포팅) |
| 나머지 (DXMT overlay, GLib symlink, codesign, wrapper) | 유지 | 유지 |

### wine-dxmt-steam.rb
- version + url + sha256 을 동일하게 업데이트 (같은 tarball 참조 → brew 가 1회만 다운로드)

### docs
- `README.md`, `README.kor.md`, `TECHNICAL.md` 도 11.6_1 → 11.7 + CW-HACK 언급 추가

## 8. 로컬 테스트 흐름 (git push 없이)

```
~/tmp/test-local-cask.sh
```

동작:
1. `/opt/homebrew/Library/Taps/zzzz465/homebrew-wine-dxmt/Casks/*.rb` 백업 → `/tmp/*.bak`
2. repo 의 수정본 복사 + `url` 을 `file:///tmp/wine-staging-11.7_cw1-osx64.tar.xz` 로 치환
3. `brew reinstall --cask wine-dxmt` + `wine-dxmt-steam`
4. 설치된 `kernelbase.dll` strings 확인

### 원복
```
cp /tmp/wine-dxmt.rb.bak      /opt/homebrew/Library/Taps/zzzz465/homebrew-wine-dxmt/Casks/wine-dxmt.rb
cp /tmp/wine-dxmt-steam.rb.bak /opt/homebrew/Library/Taps/zzzz465/homebrew-wine-dxmt/Casks/wine-dxmt-steam.rb
```

## 9. 검증 결과

| 항목 | 결과 |
|---|---|
| cask reinstall | ✅ 성공 (11.6_1 → 11.7_cw1 upgrade) |
| 설치 경로 | `~/Wine/dxmt/11.7_cw1/` |
| `kernelbase.dll` strings | `CrossOver hack changing command line to %s` ✅ |
| `wine --version` | `wine-11.7 (Staging)` ✅ |
| `wine-dxmt-steam` UI 렌더 | ✅ (11.6_1 에서는 실패했음) |
| `ps aux` 중 `--disable-gpu` 플래그 | ✅ (steamwebhelper 에 실제로 주입됨) |

### 관측된 기타 이슈 (본 작업 범위 밖)
- **Steam Service Error** 다이얼로그 — CANCEL 누르면 진행 가능. wine 공통 현상. 해결하려면 prefix 초기화 시 user 를 Admin 그룹에 등록 (winetricks 또는 wineboot 설정).
- **Dock 아이콘 2개** — Steam.exe 와 steamwebhelper.exe 가 별도 앱으로 보임. 순수 cosmetic. winemac.drv LSUIElement 처리 차원 (CW-HACK z-order 는 이걸 해결 안 함).

## 10. 아직 안 한 것 (follow-up)

1. **GitHub release + push** — 로컬 검증 완료, 아직 배포 안 함
   ```
   cd ~/Documents/git/github-cloud/homebrew-wine-dxmt
   git add Casks/ README.md README.kor.md TECHNICAL.md .gitignore CLAUDE.md
   git -c user.name=jungooji -c user.email=zzzz465@naver.com \
     commit -m "Ship custom wine-staging 11.7 build with CrossOver CEF injection"
   git tag v11.7_cw1
   git push origin main
   git push origin v11.7_cw1
   gh release create v11.7_cw1 /tmp/wine-staging-11.7_cw1-osx64.tar.xz \
     --title "v11.7_cw1" --notes "wine-staging 11.7 custom build with CrossOver CEF helper injection for Steam UI"
   ```

2. **mfreadwrite.dll 패치** — ✅ **11.8_cw1 에서 source patchfile (`proton-mfreadwrite-164af86d.diff`) 로 정식 편입**. cask postflight 의 binary 복사 단계는 제거되어 더 이상 staged patches tarball 의존 없음.

3. **CW-HACK z-order (CX HACK 19364/16565)** — popup/dropdown 자동 dismiss 문제. 실제 사용 중 체감되면 추가.
   - 필요 작업: `macdrv_force_popup_order_front()` Cocoa 측 새 구현 + unix/PE dispatch 테이블 등록 + `macdrv_ShowWindow` 에 hack 블록 추가.

4. **Steam Service Error 억제** — `wine-dxmt-steam` cask 의 wineboot 초기화 시 wine user 를 Admin 그룹에 자동 등록.

## 11. 다음 버전 bump 시 재빌드 흐름

wine 11.8 → 11.9 이 나왔다고 가정 (11.8_cw1 기준으로 일반화).

```
# 1. Portfile 갱신 (Gcenx 가 먼저 업데이트한 후)
cd ~/Documents/git/github-cloud/macports-wine
git pull origin master

# 2. 기존 patch 두 개가 새 버전에 적용 가능한지 dry-run
NEW_VER=11.9   # 새 wine 버전
cd /tmp && rm -rf wine-check && mkdir -p wine-check/dlls/{kernelbase,mfreadwrite}
curl -sL https://raw.githubusercontent.com/wine-mirror/wine/wine-${NEW_VER}/dlls/kernelbase/process.c \
  -o wine-check/dlls/kernelbase/process.c
curl -sL https://raw.githubusercontent.com/wine-mirror/wine/wine-${NEW_VER}/dlls/mfreadwrite/reader.c \
  -o wine-check/dlls/mfreadwrite/reader.c
cd wine-check
patch -p1 --dry-run < ~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/files/cw-hack-steam-cef-injection.diff
patch -p1 --dry-run < ~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/files/proton-mfreadwrite-164af86d.diff

# 3. 실패하면 patch context 수동 수정 (대개 line number fuzz 만 필요)

# 4. macports-wine fork 동기화 (upstream 이 새 버전 push 한 후)
cd ~/Documents/git/github-cloud/macports-wine
git stash push -u -m "local patches"
git pull origin main
git stash pop
cd ~/Documents/git/github-cloud/macports-wine && /opt/local/bin/portindex

# 5. 재빌드
~/tmp/wine-build.sh

# 6. 재패키징 (package-wine.py 의 VERSION = "11.9_cw1" 로 수정 후)
~/tmp/package-wine.py

# 7. cask version/sha256/url 갱신 + git push + gh release
```

deps 는 MacPorts 가 이미 설치해서 재사용 → 실제 추가 빌드 시간은 wine-staging 본체만 (30~40분).

## 12. 관련 파일 요약

| 경로 | 역할 |
|---|---|
| `~/tmp/macports-add-overlay.sh` | sources.conf 에 local overlay 등록 |
| `~/tmp/fix-overlay-perms.sh` | macports user 가 overlay 읽을 수 있게 권한 조정 |
| `~/tmp/wine-build.sh` | `sudo port install wine-staging` 실행 |
| `~/tmp/wine-build-status.sh` | 빌드 진행도 스냅샷 |
| `~/tmp/package-wine.py` | /opt/local wine install 을 Gcenx 레이아웃 tarball 로 패키징 |
| `~/tmp/test-local-cask.sh` | tap 의 cask 를 우리 수정본으로 교체하고 `file://` URL 로 reinstall |
| `~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/files/cw-hack-steam-cef-injection.diff` | 실제 CW-HACK 패치 소스 |
| `~/Documents/git/github-cloud/macports-wine/emulators/wine-devel/Portfile` | `patchfiles-append` 로 위 패치 등록 |
| `~/Documents/git/github-cloud/homebrew-wine-dxmt/Casks/wine-dxmt.rb` | 변경된 main cask |
| `~/Documents/git/github-cloud/homebrew-wine-dxmt/Casks/wine-dxmt-steam.rb` | 변경된 steam cask |
| `~/Documents/git/github-cloud/homebrew-wine-dxmt/CLAUDE.md` | 이 repo 는 worktree 예외 규정 |
| `/tmp/wine-staging-11.7_cw1-osx64.tar.xz` | 최종 빌드 tarball (216 MB) |
| `/tmp/wine-build-YYYYMMDD-HHMMSS.log` | MacPorts 빌드 로그 (35 MB) |

## 13. 디스크 사용량 / 정리 대상

- `/opt/local` 전체: ~3.0 GB (MacPorts 스택)
- `/opt/local/var/macports/distfiles`: ~593 MB — `sudo port clean --dist --all` 로 회수 가능 (다음 빌드 시 재다운로드)
- `/tmp/wine-build-*.log`: 35 MB — 필요 없으면 삭제
- `/tmp/wine-pkg-11.7/`: ~934 MB (tar 하기 전 staging dir) — 배포 완료 후 삭제 가능

## 14. 검증에 사용한 참조 소스

- Gcenx/game-porting-toolkit `dlls/kernelbase/process.c` (line 589-676 = 우리가 포팅한 CW-HACK 블록, 678-704 = 의도적으로 제외한 steam.exe hack)
- Gcenx/game-porting-toolkit `dlls/winemac.drv/window.c` (line 1893-1968 = 보류한 z-order hack)
- Gcenx/macports-wine `emulators/wine-devel/Portfile` (우리 fork 의 base)
- wine-mirror/wine `wine-11.7` 태그 (vanilla source, patch 대상)
