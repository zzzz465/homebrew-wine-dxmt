# homebrew-wine-dxmt

macOS용 wine + dxmt + 간편한 steam 설정 패키지입니다.

- wine 11 + GCENX
- dxmt 0.74
- DJMax 구동 문제 수정
  - GLib/GStreamer를 시스템 버전으로 업데이트
  - 창 크기 조정 문제에 대한 DXMT 패치
  - Gcenx CW-HACK 패치를 포함한 wine 11 빌드 (Rosetta 2 환경 구동 관련)

## 설치 방법

```bash
# Steam까지 모두 설치 (권장)
brew tap zzzz465/homebrew-wine-dxmt
brew install --cask wine-dxmt-steam

# 이미 Steam이 설치된 경우
brew tap zzzz465/homebrew-wine-dxmt
WINE_DXMT_PREFIX=/path/to/your/steam/prefix brew install --cask wine-dxmt-steam
```

## 사용법

```bash
# Steam 실행
wine-dxmt-steam

# 게임 바로 실행 (예: DJMax)
wine-dxmt-steam -applaunch 960170

# 종료
wine-dxmt-steam shutdown
```
